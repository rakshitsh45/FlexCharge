# Technical Deep Dives & Engineering FAQ

This document addresses key design decisions, control theory formulations, and grid interconnection considerations for the **FlexCharge** fast-charging station.

---

## Q1: Why was an 800V DC Bus selected instead of a conventional 400V Bus?
> **Engineering Rationale**: 
> 1. **Linear Modulation Index**: For a 415V RMS line-to-line grid, the peak phase-to-phase voltage is $\sqrt{2} \times 415 \approx 587\text{ V}$. An 800V bus ensures the Active Front End (AFE) operates comfortably in the linear modulation region ($M \approx 0.73$) without overmodulation or six-step operation.
> 2. **Current & $I^2R$ Losses**: For high-power fast charging (50 kW - 150 kW), doubling the bus voltage halves the operating current, reducing $I^2R$ cabling copper losses by 75% and lowering thermal stress on power semiconductors.
> 3. **High-Power EV Platform Compatibility**: Directly matches modern 800V EV architectures (Porsche Taycan, Hyundai E-GMP, commercial heavy-duty electric trucks).

---

## Q2: How were the PI controllers tuned, and how were the $d$-$q$ axes decoupled?
> **Engineering Rationale**: 
> Grid interface inductors introduce cross-coupling between $i_d$ and $i_q$ due to the rotation of the reference frame ($\omega L i_q$ and $-\omega L i_d$). 
> Feedforward cross-coupling decoupling was integrated into the voltage command synthesis:
> $$v_{conv,d}^* = v_{gd} + \omega L i_q - u_d$$
> $$v_{conv,q}^* = v_{gq} - \omega L i_d - u_q$$
> This decouples the multi-input multi-output (MIMO) plant into two independent single-input single-output (SISO) first-order plants $1/(Ls + R)$.
> * **Inner Current Loops**: Tuned via the **Modulus Optimum (MO)** criterion for a 1.5 ms response time ($\approx 800\text{ Hz}$ bandwidth).
> * **Outer DC Bus Voltage Loop**: Tuned using the **Symmetrical Optimum (SO)** method to maximize phase margin and optimize disturbance rejection against step load disconnections.

---

## Q3: How does the system handle voltage sags according to IEEE 1547-2018?
> **Engineering Rationale**: 
> During a 12% grid sag ($V_{pu} = 0.88$), drawing 30 kW of active charging power would worsen the local distribution feeder sag. 
> The supervisory logic shifts the DC-DC port into standby ($I_{bat} = 0\text{ A}$), shedding the active load within $4\text{ ms}$. 
> Simultaneously, the AFE controller commands a negative quadrature current $i_{gq}^* = -40\text{ A}$, which injects $+17.89\text{ kVAR}$ of capacitive reactive power into the distribution grid, raising the Point of Common Coupling (PCC) voltage and stabilizing the grid.

---

## Q4: How is THD maintained below 5% during bidirectional power reversal?
> **Engineering Rationale**: 
> In V2G mode, the converter transitions from a rectifier to a grid-feeding inverter. By maintaining continuous grid angle tracking with a second-order SRF-PLL and applying sinusoidal PWM with carrier frequency interleaving at 10 kHz, harmonics are pushed into high-frequency sidebands away from the fundamental. 
> The 50-order FFT audit proved the 5th and 7th harmonics remained at 1.4% and 0.9% respectively, resulting in a total current THD of **$1.71\%$**, well below the IEEE 519 limit of $5.0\%$.
