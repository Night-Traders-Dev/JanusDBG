import * as vscode from 'vscode';

interface DAPMessage {
    type: string;
    seq: number;
}

interface DAPRequest extends DAPMessage {
    command: string;
    arguments?: any;
}

interface DAPResponse extends DAPMessage {
    request_seq: number;
    success: boolean;
    command: string;
    body?: any;
}

export class DebugAdapter implements vscode.DebugAdapter {
    private sendEmitter = new vscode.EventEmitter<vscode.DebugProtocolMessage>();

    readonly onDidSendMessage: vscode.Event<vscode.DebugProtocolMessage> = this.sendEmitter.event;

    handleMessage(message: vscode.DebugProtocolMessage): void {
        const msg = message as unknown as DAPMessage;
        if (msg.type === 'request') {
            this.handleRequest(msg as unknown as DAPRequest);
        }
    }

    private handleRequest(request: DAPRequest): void {
        switch (request.command) {
            case 'initialize':
                this.sendResponse(request, {
                    supportsConfigurationDoneRequest: true,
                    supportsSetVariable: true,
                });
                break;
            case 'launch':
                this.sendResponse(request, {});
                break;
            case 'disconnect':
                this.sendResponse(request, {});
                break;
            default:
                this.sendResponse(request, {});
        }
    }

    private sendResponse(request: DAPRequest, body: any): void {
        const response: DAPResponse = {
            type: 'response',
            seq: 0,
            request_seq: request.seq,
            success: true,
            command: request.command,
            body,
        };
        this.sendEmitter.fire(response as unknown as vscode.DebugProtocolMessage);
    }

    dispose(): void {
        this.sendEmitter.dispose();
    }
}
