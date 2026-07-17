import * as vscode from 'vscode';
import { DebugAdapter } from './debugAdapter';

let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('JanusDBG');
    outputChannel.appendLine('JanusDBG extension activated');

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.start', () => {
            outputChannel.appendLine('Starting JanusDBG backend...');
            vscode.window.showInformationMessage('JanusDBG: Starting backend');
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.attachARM', () => {
            outputChannel.appendLine('Attaching to ARM...');
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.attachRV', () => {
            outputChannel.appendLine('Attaching to RISC-V...');
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.setCrossBreakpoint', () => {
            outputChannel.appendLine('Setting cross breakpoint...');
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('janusdbg.recordTimeline', () => {
            outputChannel.appendLine('Recording timeline...');
        })
    );

    context.subscriptions.push(
        vscode.debug.registerDebugAdapterDescriptorFactory('janusdbg', {
            createDebugAdapterDescriptor(session) {
                return new vscode.DebugAdapterInlineImplementation(
                    new DebugAdapter()
                );
            }
        })
    );
}

export function deactivate() {
    outputChannel?.dispose();
}
