import * as vscode from 'vscode';
import { DebugAdapter } from './debugAdapter';

let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('JanusDBG');
    outputChannel.appendLine('JanusDBG extension activated');

    let rpcConnection: any = null;
    let flameGraphPanel: vscode.WebviewPanel | undefined;

    async function connectToBackend(host: string, port: number): Promise<void> {
        const net = require('net');
        outputChannel.appendLine(`Connecting to RPC server at ${host}:${port}`);
        await new Promise<void>((resolve, reject) => {
            rpcConnection = net.connect(port, host, () => {
                outputChannel.appendLine('[rpc] Connected to backend');
                resolve();
            });

            rpcConnection.on('data', (data: any) => {
                try {
                    const response = JSON.parse(data.toString());
                    outputChannel.appendLine(`[rpc] response: ${JSON.stringify(response, null, 2)}`);
                    if (flameGraphPanel && (response.name === 'root' || response.type === 'flamegraph' || response.flamegraph)) {
                        const flameData = response.flamegraph || (response.name === 'root' ? response : null);
                        if (flameData) {
                            flameGraphPanel.webview.postMessage({ command: 'loadFlameGraph', data: flameData });
                        }
                    }
                } catch (err) {
                    outputChannel.appendLine(`[error] Failed to parse response: ${err}`);
                }
            });

            rpcConnection.on('error', (err: any) => {
                outputChannel.appendLine(`[error] Connection error: ${err.message}`);
                reject(err);
            });

            rpcConnection.on('end', () => {
                outputChannel.appendLine('[rpc] Connection ended');
                if (rpcConnection) {
                    rpcConnection.destroy();
                }
                rpcConnection = null;
            });
        });
    }

    function sendRpcRequest(method: string, params: any): void {
        if (rpcConnection && rpcConnection.write) {
            const request = {
                jsonrpc: '2.0',
                method,
                params,
                id: 1,
            };
            const requestStr = JSON.stringify(request) + '\n';
            try {
                rpcConnection.write(requestStr);
            } catch (err) {
                outputChannel.appendLine(`[error] Failed to send RPC request: ${err}`);
            }
        } else {
            outputChannel.appendLine(`[error] Not connected to RPC server`);
        }
    }

    const debugAdapter = new DebugAdapter(outputChannel);

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.start', async () => {
            outputChannel.appendLine('Starting JanusDBG backend...');
            vscode.window.showInformationMessage('JanusDBG: Starting backend');
            await debugAdapter.connectToBackend('localhost', 8179);
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.attachARM', () => {
            outputChannel.appendLine('Attaching to ARM...');
            sendRpcRequest('halt', { session: 'arm' });
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.attachRV', () => {
            outputChannel.appendLine('Attaching to RISC-V...');
            sendRpcRequest('halt', { session: 'rv' });
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.setCrossBreakpoint', () => {
            outputChannel.appendLine('Setting cross breakpoint...');
            sendRpcRequest('syncSetBreakpoint', { sessions: ['arm', 'rv'], addr: '*0x8000' });
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.recordTimeline', () => {
            outputChannel.appendLine('Recording timeline...');
            sendRpcRequest('startTimelineRecording', {});
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.showFlameGraph', () => {
            if (flameGraphPanel) {
                flameGraphPanel.reveal(vscode.ViewColumn.One);
            } else {
                flameGraphPanel = vscode.window.createWebviewPanel(
                    'janusdbgFlameGraph',
                    'JanusDBG: Flame Graph',
                    vscode.ViewColumn.One,
                    { enableScripts: true }
                );
                flameGraphPanel.webview.html = getFlameGraphHtml();
                flameGraphPanel.onDidDispose(() => {
                    flameGraphPanel = undefined;
                }, null, context.subscriptions);
            }
            // Send a request to the backend to get the flame graph if necessary, 
            // though the prompt implies it might be provided automatically.
            // sendRpcRequest('getFlameGraph', {});
        })
    );

    context.subscriptions.push(
        vscode.debug.registerDebugAdapterDescriptorFactory('janusdbg', {
            createDebugAdapterDescriptor(session: vscode.DebugSession): vscode.DebugAdapterDescriptor {
                outputChannel.appendLine('Creating debug adapter');
                const inlineAdapter = new vscode.DebugAdapterInlineImplementation(debugAdapter);
                return inlineAdapter;
            }
        })
    );

    context.subscriptions.push(debugAdapter);
}

export function deactivate() {
    outputChannel?.dispose();
}

function getFlameGraphHtml(): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Flame Graph</title>
    <style>
        body {
            font-family: var(--vscode-font-family), sans-serif;
            background-color: var(--vscode-editor-background);
            color: var(--vscode-editor-foreground);
            padding: 20px;
        }
        #flamegraph-container {
            display: flex;
            flex-direction: column;
            width: 100%;
            height: 100%;
            overflow-x: auto;
            margin-top: 20px;
        }
        .flame-node {
            display: flex;
            flex-direction: column-reverse;
            width: 100%;
        }
        .flame-label {
            border: 1px solid var(--vscode-editor-background);
            box-sizing: border-box;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            padding: 2px 4px;
            font-size: 12px;
            height: 22px;
            cursor: pointer;
            color: #000;
        }
        .flame-label:hover {
            filter: brightness(1.2);
        }
        .flame-children {
            display: flex;
            flex-direction: row;
            width: 100%;
        }
    </style>
</head>
<body>
    <h2>Flame Graph</h2>
    <div id="flamegraph-container">
        <p>Waiting for flame graph data from backend...</p>
    </div>

    <script>
        window.addEventListener('message', event => {
            const message = event.data;
            if (message.command === 'loadFlameGraph') {
                renderFlameGraph(message.data);
            }
        });

        function renderFlameGraph(data) {
            const container = document.getElementById('flamegraph-container');
            container.innerHTML = '';

            // Compute values if missing (bottom-up sum)
            function computeValue(node) {
                if (node.children && node.children.length > 0) {
                    let sum = 0;
                    node.children.forEach(c => sum += computeValue(c));
                    if (node.value < sum) node.value = sum;
                }
                return node.value || 0;
            }
            computeValue(data);

            function createNode(node, totalParentValue) {
                const el = document.createElement('div');
                el.className = 'flame-node';
                
                // Calculate width percentage
                const pct = totalParentValue > 0 ? (node.value / totalParentValue) * 100 : 100;
                el.style.width = pct + '%';
                
                const label = document.createElement('div');
                label.className = 'flame-label';
                label.textContent = node.name + (node.value ? \` (\${node.value})\` : '');
                label.title = label.textContent;

                // Simple hash for consistent color
                let hash = 0;
                for (let i = 0; i < node.name.length; i++) {
                    hash = node.name.charCodeAt(i) + ((hash << 5) - hash);
                }
                const hue = 10 + (Math.abs(hash) % 40);
                label.style.backgroundColor = \`hsl(\${hue}, 80%, 60%)\`;

                el.appendChild(label);

                if (node.children && node.children.length > 0) {
                    const childrenContainer = document.createElement('div');
                    childrenContainer.className = 'flame-children';
                    node.children.forEach(child => {
                        childrenContainer.appendChild(createNode(child, node.value));
                    });
                    el.appendChild(childrenContainer);
                }

                return el;
            }

            if (data && data.name) {
                container.appendChild(createNode(data, data.value));
            } else {
                container.innerHTML = '<p>Invalid flame graph data received.</p>';
            }
        }
    </script>
</body>
</html>`;
}
