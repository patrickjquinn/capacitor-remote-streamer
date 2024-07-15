import { registerPlugin } from '@capacitor/core';

import type { RemoteStreamerPlugin } from './definitions';

const RemoteStreamer = registerPlugin<RemoteStreamerPlugin>('RemoteStreamer', {
  web: () => import('./web').then(m => new m.RemoteStreamerWeb()),
});

export * from './definitions';
export { RemoteStreamer };
