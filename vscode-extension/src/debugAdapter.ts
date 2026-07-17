import * as vscode from 'vscode';
import { spawn } from 'child_process';
import { resolve } from 'path';

export class DebugAdapter implements vscode.DebugAdapter {
    private outputChannel: vscode.OutputChannel;
    private seq: number = 1;
    private rpcConnection: any = null;
    private backendProcess: any = null;
    private nextSeq: number = 1;

    constructor(outputChannel: vscode.OutputChannel) {
        this.outputChannel = outputChannel;
    }

    private _sendMessage = new vscode.EventEmitter<vscode.DebugProtocolMessage>();
    public readonly onDidSendMessage: vscode.Event<vscode.DebugProtocolMessage> = this._sendMessage.event;

    public handleMessage(message: vscode.DebugProtocolMessage): void {
        this.outputChannel.appendLine(`[dap] received: ${JSON.stringify(message, null, 2)}`);
        if (message.type === 'request') {
            const request = message as import('vscode-debugprotocol').DebugProtocol.Request;
            const response: import('vscode-debugprotocol').DebugProtocol.Response = {
                type: 'response',
                seq: 0,
                request_seq: request.seq,
                success: true,
                command: request.command
            };
            if (request.command === 'initialize') {
                response.body = {
                    supportsConfigurationDoneRequest: true,
                };
                this._sendMessage.fire(response);
                this._sendMessage.fire({
                    type: 'event',
                    event: 'initialized',
                    seq: 0
                });
            } else if (request.command === 'launch' || request.command === 'attach') {
                this.startBackend();
                this._sendMessage.fire(response);
            } else if (request.command === 'configurationDone') {
                this._sendMessage.fire(response);
            } else if (request.command === 'threads') {
                response.body = {
                    threads: [
                        { id: 1, name: "ARM Cortex-A" },
                        { id: 2, name: "RISC-V" }
                    ]
                };
                this._sendMessage.fire(response);
            } else if (request.command === 'disconnect') {
                this.stopBackend();
                this._sendMessage.fire(response);
            } else {
                this._sendMessage.fire(response); // Auto-ack other requests
            }
        }
    }

    public async startBackend(): Promise<void> {
        if (this.backendProcess != null) {
            return;
        }

        this.outputChannel.appendLine('Starting JanusDBG backend...');
        const bundlePath = resolve(__dirname, '../../build/janusdbgd_native');

        this.outputChannel.appendLine(`Running: ${bundlePath}`);
        this.backendProcess = spawn(bundlePath, {
            stdio: ['pipe', 'pipe', 'pipe'],
            cwd: resolve(__dirname, '../../'),
        });

        this.backendProcess.stdout?.on('data', (data: any) => {
            this.outputChannel.appendLine(`[backend] ${data.toString().trim()}`);
        });

        this.backendProcess.stderr?.on('data', (data: any) => {
            this.outputChannel.appendLine(`[backend error] ${data.toString().trim()}`);
        });

        this.backendProcess.on('error', (err: any) => {
            this.outputChannel.appendLine(`[backend error] ${err.message}`);
        });

        this.backendProcess.on('exit', (code: any) => {
            this.outputChannel.appendLine(`[backend exited] code ${code}`);
            this.backendProcess = null;
        });

        await new Promise<void>((resolve) => {
            setTimeout(() => {
                this.sendRpcRequest('getSessions', {});
                resolve();
            }, 1000);
        });
    }

    private connectToBackend(host: string, port: number): Promise<void> {
        return new Promise<void>((resolve, reject) => {
            const net = require('net');
            this.outputChannel.appendLine(`Connecting to RPC server at ${host}:${port}`);
            this.rpcConnection = net.connect(port, host, () => {
                this.outputChannel.appendLine('[rpc] Connected to backend');
                resolve();
            });

            this.rpcConnection.on('data', (data: any) => {
                try {
                    const response = JSON.parse(data.toString());
                    this.outputChannel.appendLine(`[rpc] response: ${JSON.stringify(response, null, 2)}`);
                } catch (err) {
                    this.outputChannel.appendLine(`[error] Failed to parse response: ${err}`);
                }
            });

            this.rpcConnection.on('error', (err: any) => {
                this.outputChannel.appendLine(`[error] Connection error: ${err.message}`);
                reject(err);
            });

            this.rpcConnection.on('end', () => {
                this.outputChannel.appendLine('[rpc] Connection ended');
                if (this.rpcConnection) {
                    this.rpcConnection.destroy();
                }
                this.rpcConnection = null;
            });
        });
    }

    private sendRpcRequest(method: string, params: any): void {
        if (this.rpcConnection && this.rpcConnection.write) {
            const request = {
                jsonrpc: '2.0',
                method,
                params,
                id: this.nextSeq++,
            };
            const requestStr = JSON.stringify(request) + '\n';
            try {
                this.rpcConnection.write(requestStr);
            } catch (err) {
                this.outputChannel.appendLine(`[error] Failed to send RPC request: ${err}`);
            }
        } else {
            this.outputChannel.appendLine(`[error] Not connected to RPC server`);
        }
    }

    public stopBackend(): void {
        this.sendRpcRequest('disconnect', { session: 'arm' });
        if (this.backendProcess != null) {
            this.backendProcess.kill();
            this.backendProcess = null;
        }
    }

    public dispose(): void {
        this.stopBackend();
        if (this.rpcConnection) {
            this.rpcConnection.destroy();
            this.rpcConnection = null;
        }
    }
}
