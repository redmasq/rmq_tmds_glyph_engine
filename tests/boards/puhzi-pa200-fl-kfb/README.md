# Puhzi PA200-FL-KFB Tests

Board-specific test overrides and notes for Puhzi PA200-FL-KFB belong here.

The first shared UART reset validation currently uses the common playlist under
`resources/test_playlists/`.

Current host note:

- the Artix UART path is a standalone CH340 serial device rather than the
  shared WSL2 FTDI/programmer bridge used on the Gowin boards
- the harness should try to discover the shared CH340 tty automatically
- if it is not currently forwarded into WSL, the harness should emit a concrete
  `usbipd attach --wsl --busid ...` hint
