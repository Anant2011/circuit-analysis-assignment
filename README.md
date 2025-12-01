# circuit-analysis-assignment
Developed a MATLAB-based circuit simulator for RLC circuits driven by independent DC sources, performing both steady-state and transient analysis with comprehensive results plotting.


# Linear Circuit Lab 

This project is a fully functional graphical user interface (GUI) circuit simulator developed in MATLAB. It allows users to visually build linear circuits and perform both DC operating point and Transient (Time-Domain) analysis using the **Modified Nodal Analysis (MNA)** technique.

The application supports fundamental passive components (R, L, C) and independent sources (V, I), making it an excellent demonstration of circuit theory implementation 

## ✨ Key Technical Highlights

The simulator is built entirely with MATLAB scripting and handles all core circuit analysis tasks:

### 1. Circuit Construction and GUI
* **Interactive Canvas:** Drag-and-drop-like interface for placing Resistors (R), Capacitors (C), Inductors (L), Independent Voltage Sources (V), and Independent Current Sources (I).
* **Node Abstraction:** Automatically identifies and merges connection points (nodes) based on wires and component terminals, essential for MNA formulation.
* **Grounding:** Supports user-defined ground node setting, crucial for MNA reference.

### 2. Simulation Engine (Modified Nodal Analysis - MNA)
* **Netlist Generation:** Internally maps the graphical representation to a netlist of branches and nodes.
* **DC Analysis (`Simulate DC`):** Solves the circuit for the DC steady-state operating point.
* **Transient Analysis (`Simulate Transient`):**
    * Uses the **Backward Euler Method** for time-stepping.
    * Formulates the time-domain MNA matrix by applying the **companion model** for capacitors and inductors at each time step.

### 3. Probing and Results
* **DC Results:** Outputs a table of DC node voltages and a bar chart of DC branch currents.
* **Transient Plotting:** Allows users to **probe** any node to view its voltage over time $V(t)$ or any branch to view both its voltage $V(t)$ and current $I(t)$ time traces.

## 📚 Methodology and References

The implementation of the DC and Transient Analysis utilizes core techniques from circuit simulation theory, primarily based on the **Modified Nodal Analysis (MNA)** method.

* **Reference Text:**
    * **Circuit Simulation** by Farid N. Najm (IEEE Press).
    * *The approach for formulating the MNA matrix, stamping components (like R, V, I), and implementing the Backward Euler method for time integration (specifically for C and L companion models) was guided by this textbook.*

## 🛠️ How to Run the Simulator

1.  Download or clone this repository.
2.  Open **MATLAB**.
3.  Navigate to the directory containing `linear_circuit_lab5.m`.
4.  Run the function from the MATLAB command window:
5.  Use the toolbar buttons to build a circuit on the black canvas, set a ground node, and click **`Simulate DC`** or **`Simulate Transient`** to run the analysis.

## 🔑 Relevant Skills Demonstrated

* **Circuit Theory Implementation**
* **Modified Nodal Analysis (MNA)**
* **Numerical Methods for ODEs (Backward Euler/Trapezoidal Rule)**
* **DC and Transient Analysis**

