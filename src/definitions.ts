export interface RemoteStreamerPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
