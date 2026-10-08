# Control System Design, Decoupling & Controller Tuning

## 1. Dual-Loop Control Hierarchy

The control architecture of the **FlexCharge** fast-charging station is organized into two nested loops operating across different frequency bandwidths to ensure stability, fast disturbance rejection, and zero steady-state error.

```
+---------------------------------------------------------------------------------------------------------+
|                                  DUAL-LOOP CONTROL HIERARCHY                                            |
+---------------------------------------------------------------------------------------------------------+

   [ Supervisory Grid Signal ] --------+
                                       |
   [ Common DC Bus V_dc ]              v
             |               +-----------------------+              +-----------------------+
   (800V Ref)+--->( + - )--->|   OUTER VOLTAGE LOOP  |--i_gd_ref--->|  INNER CURRENT LOOP   |---> PWM
                             | (Symmetrical Optimum) |              |   (Modulus Optimum)   |     Modulation
                             +-----------------------+              +-----------------------+     Signals
                                                                               ^
   [ Grid Voltage Sag Sensor ] -------> i_gq_ref ------------------------------+
                                       (UPF or Reactive)
```

---

## 2. Active Front End (AFE) Control Design

### Synchronous Reference Frame (SRF $d$-$q$) Vector Control
Grid synchronization is maintained using a **Second-Order Synchronous Reference Frame Phase-Locked Loop (SRF-PLL)**, producing the grid transformation angle $\theta(t) = \int \omega_g dt$.

With the reference frame oriented such that the grid voltage phase aligns with the $d$-axis:
$$v_{gd} = V_{pk} \approx 338.84\text{ V}, \quad v_{gq} = 0\text{ V}$$

Under this alignment, instantaneous active and reactive powers simplify directly to decoupled current components:
$$P = \frac{3}{2} v_{gd} i_{gd}$$
$$Q = -\frac{3}{2} v_{gd} i_{gq}$$

* **Active Power ($P$)** is controlled solely by the direct-axis current $i_{gd}$.
* **Reactive Power ($Q$)** is controlled solely by the quadrature-axis current $i_{gq}$.

### Inner Current Loop Decoupling & Modulus Optimum Tuning
The plant transfer function for the grid inductors is:
$$G_i(s) = \frac{I_g(s)}{V(s)} = \frac{1}{L_{grid} s + R_{grid}}$$

To eliminate cross-coupling terms ($\omega L i_{gq}$ and $-\omega L i_{gd}$), the controller outputs are defined as:
$$v_{conv,d}^* = v_{gd} + \omega_g L_{grid} i_{gq} - u_d$$
$$v_{conv,q}^* = v_{gq} - \omega_g L_{grid} i_{gd} - u_q$$

Where $u_d, u_q$ are the outputs of identical Proportional-Integral (PI) controllers:
$$u_d(t) = K_{p,i} (i_{gd}^* - i_{gd}) + K_{i,i} \int (i_{gd}^* - i_{gd}) dt$$
$$u_q(t) = K_{p,i} (i_{gq}^* - i_{gq}) + K_{i,i} \int (i_{gq}^* - i_{gq}) dt$$

Tuned using the **Modulus Optimum (MO)** criterion for a closed-loop bandwidth of $\approx 800\text{ Hz}$ ($\tau_i = 1.5\text{ ms}$):
* $K_{p,i} = \frac{L_{grid}}{2 T_{delay}} = 12.5\text{ V/A}$
* $K_{i,i} = \frac{R_{grid}}{2 T_{delay}} = 950.0\text{ V/(A}\cdot\text{s)}$

### Outer DC Voltage Loop & Symmetrical Optimum Tuning
The DC-link capacitor voltage responds according to:
$$C_{dc} \frac{d V_{dc}}{dt} = i_{afe,dc} - i_{dcdc,dc}$$

Linearizing the power transfer around nominal operating point ($V_{dc,nom} = 800\text{ V}$):
$$P_{ac} \approx \frac{3}{2} v_{gd} i_{gd} \implies i_{afe,dc} \approx \frac{1.5 V_{pk}}{V_{dc,nom}} i_{gd} = K_{conv} \cdot i_{gd}$$
Where $K_{conv} = \frac{1.5 \times 338.84}{800} \approx 0.635$.

The outer loop is tuned via **Symmetrical Optimum (SO)** to optimize disturbance rejection and phase margin:
* $K_{p,dc} = 1.45\text{ A/V}$
* $K_{i,dc} = 28.0\text{ A/(V}\cdot\text{s)}$
* Anti-windup clamping: $I_{d,max} = \pm 120\text{ A}$

---

## 3. DC-DC Converter Control: CC-CV & V2G Architecture

### Constant Current / Constant Voltage (CC-CV) State Machine
During Grid-to-Vehicle (**G2V**) charging:
1. **Low SoC Stage ($\text{SoC} < 80\%$ and $V_{bat} < 420\text{ V}$)**:
   * Operates in **Constant Current (CC)** mode.
   * Inductor current reference is clamped to maximum safe fast-charging rate:
     $$I_{bat}^* = +75.0\text{ A} \quad (\approx 30.0\text{ kW})$$
2. **High SoC Stage ($\text{SoC} \ge 80\%$ or $V_{bat} \ge 420.0\text{ V}$)**:
   * Seamlessly switches to **Constant Voltage (CV)** mode to prevent lithium plating and thermal runaway.
   * An outer voltage PI loop throttles charging current dynamically:
     $$I_{bat}^* = K_{p,vb}(420.0 - V_{bat}) + K_{i,vb} \int (420.0 - V_{bat}) dt$$
     with $I_{bat}^* \in [0.0\text{ A}, 75.0\text{ A}]$.

```
         +-----------------------+
         |     Plug-in (G2V)     |
         |      SoC = 25%        |
         +-----------------------+
                     |
                     v
         +-----------------------+
         |   Constant Current    |
         |      (CC Mode)        |--------+
         |     I_bat = +75A      |        |
         +-----------------------+        |
                     |                    |
            [ SoC >= 80% or ]             | [ External Utility ]
            [ V_bat >= 420V ]             | [ Peak Signal ]
                     |                    |
                     v                    v
         +-----------------------+  +-------------------------+
         |   Constant Voltage    |  |       V2G Discharging   |
         |      (CV Mode)        |  |         (Peak Shaving)  |
         |  V_bat = 420V clamp   |  |        I_bat = -60.0A   |
         +-----------------------+  +-------------------------+
```

### Vehicle-to-Grid (V2G) Peak Demand Response
When the supervisory utility controller commands peak shaving ($Mode = 3$):
* The CC-CV loop is overridden.
* Battery current reference reverses to discharging setpoint:
  $$I_{bat}^* = -60.0\text{ A} \quad (\approx 24.0\text{ kW})$$
* Power flows from the battery pack into the $800\text{ V}$ DC bus, elevating $V_{dc}$.
* The outer DC bus voltage controller detects the energy influx and drives $i_{gd}^* < 0$ (negative direct-axis current), commanding the AFE to invert and inject clean active power into the distribution grid.

---

## 4. Grid Stress & Voltage Sag Reactive Power Support

In compliance with **IEEE 1547-2018**, the charging station provides dynamic reactive voltage support during abnormal grid conditions:

1. **Sag Detection**: Continuous monitoring of terminal voltage magnitude:
   $$V_{pu} = \frac{\sqrt{v_{gd}^2 + v_{gq}^2}}{V_{grid,peak}}$$
2. **Threshold Trigger**: If $V_{pu} < 0.90$ (e.g., 12% sag where $V_{pu} = 0.88$):
   * Battery charging is immediately curtailed: $I_{bat}^* \to 0.0\text{ A}$ (Standby).
   * Quadrature current reference is computed proportionally:
     $$i_{gq}^* = -K_{reactive} \cdot (1.0 - V_{pu}) = -40.0\text{ A}$$
   * The AFE operates as a STATCOM, injecting $+17.89\text{ kVAR}$ of capacitive reactive power to raise the local Point of Common Coupling (PCC) voltage.
