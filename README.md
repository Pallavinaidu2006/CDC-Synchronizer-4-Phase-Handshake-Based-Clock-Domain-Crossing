# CDC-Synchronizer-4-Phase-Handshake-Based-Clock-Domain-Crossing
A Verilog design that safely transfers an 8-bit data bus between two independent clock domains using a 4-phase request/acknowledge handshake and double flip-flop synchronizers.

Why this exists:

Signals moving between two clocks that aren't related can cause metastability — an unpredictable, unstable output. This project shows the standard fix.
Single-bit control signals (req, ack) -> passed through a 2-flip-flop synchronizer.
The 8-bit data bus -> not synchronized directly. It's held stable by the sender for the whole handshake, so the receiver can safely read it once the handshake confirms it's ready.


Verified with 2000 randomized transfers, using two clocks running at unrelated speeds — 0 errors.


Files:

File                 What it does
sync_2ff.v           2-flip-flop synchronizer for single-bit signals
cdc_handshake.v      Sender + receiver FSMs implementing the handshake
cdc_top.v            Top-level wrapper
tb_cdc.v             Self-checking testbench 

How the transfer works:

Sender loads data, raises req, and holds both steady.
req crosses into the receiver's clock domain through the synchronizer (2-cycle delay).
Receiver sees req, grabs the data, raises ack.
ack crosses back through a second synchronizer.
Sender sees ack, drops req — everything resets and the cycle repeats for the next transfer.
