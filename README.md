# ARM Assembly : GPIO Button and Timer Pre-emption interrupts on Sitara

Amanda Falke 2015

ARM Assembly with the Sitara processor; GPIO button interrupts, pre-emptive timer interrupts.

Hook and chain vector table method.

PIN MAPPING for MUXes (selecting user GPIO as per commonly found on Raspbery Pi/ other GPIO work.

The counter on this processor is an up-counter. That's what's used for the preemption. 

The LED pulses when the button is pushed, and each pulse is governed by the up counter's preemption, for each "flash."

The pulsing stops when the button is pressed for a second time, and resumed when pressed a third time, and so on.
