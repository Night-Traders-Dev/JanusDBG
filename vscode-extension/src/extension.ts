import * as vscode from 'vscode';
import { DebugAdapter } from './debugAdapter';

let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('JanusDBG');
    outputChannel.appendLine('JanusDBG extension activated');

    let rpcConnection: any = null;

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
