'use strict';

const { contextBridge } = require('electron');

if (window.location.hostname === 'notebooklm.google.com') {
  contextBridge.exposeInMainWorld('notebooklmDesktop', {
    platform: process.platform,
    isDesktopWrapper: true,
  });
}
