import * as vscode from 'vscode';

export class DebugAdapter implements vscode.DebugAdapter {
    private send: ((message: vscode.DebugProtocolMessage) => void) | undefined;

    handleMessage(message: vscode.DebugProtocolMessage): void {
        const msg = message as vscode.DebugProtocolMessage;

        switch (msg.type) {
            case 'request':
                this.handleRequest(msg as vscode.DebugProtocolRequest);
                break;
            case 'event':
                break;
            case 'response':
                break;
        }
    }

    private handleRequest(request: vscode.DebugProtocolRequest) {
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

    private sendResponse(request: vscode.DebugProtocolRequest, body: any) {
        if (this.send) {
            this.send({
                type: 'response',
                request_seq: request.seq,
                success: true,
                command: request.command,
                body,
            } as vscode.DebugProtocolResponse);
        }
    }

    onDidSendMessage(
        callback: (message: vscode.DebugProtocolMessage) => void
    ): void {
        this.send = callback;
    }
}
