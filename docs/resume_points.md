# High-Impact Resume Bullet Points & Interview Talking Guide

> **Instructions for Use**: Copy and customize these bullet points for your resume, LinkedIn experience section, or project portfolio. Tailored for Tier-1 EV OEMs (**Ather, Ola Electric, Tesla**), utilities (**Tata Power, BESCOM, National Grid**), and power semiconductor firms (**Texas Instruments, Infineon, STMicroelectronics**).

---

## 1. Resume Bullet Points (XYZ Format: Accomplished X, Measured by Y, by Doing Z)

### Option 1: For Power Electronics / Hardware Controls Roles
* **Developed a Level-3 Bidirectional DC Fast Charging Station (800V DC Bus, 50 kW)** in MATLAB/Simulink featuring a 3-phase Active Front End (AFE) and synchronous Buck-Boost stage for G2V charging and V2G grid support.
* **Designed a dual-loop Synchronous Reference Frame ($d$-$q$) vector controller** with feedforward decoupling, achieving **Unity Power Factor ($\cos\phi = 1.000$)** and restricting common DC bus voltage deviation to **$<\pm 0.18\%$** under full 50 kW load steps.
* **Engineered dynamic grid voltage sag compensation (IEEE 1547-2018)** injecting **$+17.89\text{ kVAR}$ reactive power** within $1.8\text{ ms}$ of a 12% distribution grid sag, preventing feeder collapse while automatically derating EV load.
* **Conducted IEEE 519-2022 harmonic analysis via 50-order FFT spectral decomposition**, validating a grid current **$\text{THD}_I$ of $1.71\%$** (65% margin below the 5.0% regulatory ceiling) during full regenerative V2G peak shaving.

### Option 2: For EV Powertrain & Battery Systems Roles
* **Architected a closed-loop CC-CV battery charging state machine for a 60 kWh Li-Ion pack**, executing constant-current fast charging at **$+75\text{ A}$** with automatic transition to constant-voltage regulation at 80% SoC to protect cell chemistry.
* **Implemented bidirectional V2G peak demand response algorithm**, delivering **$22.2\text{ kW}$ back into the AC distribution grid** upon supervisory utility dispatch with zero bus instability and seamless $180^\circ$ phase inversion.
* **Formulated a strictly causal, discrete state-space dynamic model ($10\ \mu\text{s}$ step size)** eliminating algebraic loops and achieving $97.02\%$ grid-to-battery one-way conversion efficiency.

---

## 2. Technical Interview Talking Points & Deep Dives

### Q1: Why did you choose an 800V DC Bus instead of a standard 400V Bus?
> **Answer**: "Choosing 800V addresses three key engineering constraints:
> 1. **Modulation Index**: For a 415V RMS line-to-line grid, the peak line voltage is $\sqrt{2} \times 415 \approx 587\text{ V}$. An 800V bus ensures the converter operates comfortably in the linear modulation region ($M \approx 0.73$) without overmodulation or pulse dropping.
> 2. **Current & $I^2R$ Losses**: For high-power fast charging (50 kW - 150 kW), doubling the bus voltage halves the conductor current, reducing cabling $I^2R$ copper losses by 75% and thermal stress on power semiconductors.
> 3. **Future Compatibility**: Matches 800V EV architectures like Porsche Taycan, Hyundai E-GMP, and next-generation Indian commercial bus/fleet platforms."

### Q2: How did you tune the PI controllers, and how did you decouple the $d$-$q$ axes?
> **Answer**: 
> "The grid inductors introduce cross-coupling between $i_d$ and $i_q$ due to the rotation of the reference frame ($\omega L i_q$ and $-\omega L i_d$). 
> I implemented feedforward decoupling into the voltage command synthesis:
> $$v_{conv,d}^* = v_{gd} + \omega L i_q - u_d$$
> $$v_{conv,q}^* = v_{gq} - \omega L i_d - u_q$$
> This cancels the cross-axis cross-talk, transforming the plant into two independent first-order systems $1/(Ls + R)$.
> I tuned the inner current loop using the **Modulus Optimum (MO)** criterion for a 1.5 ms response time ($\approx 800\text{ Hz}$ bandwidth), and tuned the outer DC bus voltage loop using the **Symmetrical Optimum (SO)** method to maximize phase margin and optimize disturbance rejection against sudden EV disconnections."

### Q3: How does the system handle voltage sags according to IEEE 1547?
> **Answer**: 
> "During a 12% grid sag ($V_{pu} = 0.88$), drawing 30 kW of active charging power would worsen the local distribution feeder sag. 
> The supervisory logic immediately shifts the DC-DC port into standby ($I_{bat} = 0\text{ A}$), shedding the active load in $4\text{ ms}$. 
> Simultaneously, the AFE controller commands a negative quadrature current $i_{gq}^* = -40\text{ A}$, which injects $+17.89\text{ kVAR}$ of capacitive reactive power into the distribution grid, raising the Point of Common Coupling (PCC) voltage and stabilizing the grid."

### Q4: How is THD kept below 5% during bidirectional power reversal?
> **Answer**: 
> "In V2G mode, the converter changes from a rectifier to a grid-feeding inverter. By ensuring continuous angle tracking with a second-order SRF-PLL and applying sinusoidal PWM with carrier frequency interleaving at 10 kHz, harmonics are pushed into the sidebands away from the fundamental. 
> The 50-order FFT audit proved the 5th and 7th harmonics remained at 1.4% and 0.9% respectively, resulting in a total current THD of **$1.71\%$**, well below the IEEE 519 limit of $5.0\%$."
