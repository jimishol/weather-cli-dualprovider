# HEADPHONE_VIRTUALIZATION_GUIDE.md

> [!IMPORTANT]
> **Hardware & Preference Note:** The configurations and commands below are calibrated for my personal hardware (**Beyerdynamic DT 990 Pro** and **Sennheiser IE 200**) and my spatial preference (**SADIE D02**). If you use different headphones, you should swap the EQ values with data from AutoEQ.app.

## 1. The Core Philosophy
Instead of running a generic room effect, this methodology uses a "Baking" process: 
* We take a raw spatial impulse response (**SADIE**).
* We "infuse" it with precise headphone correction data (**AutoEQ**).
* The result is a single `.wav` file that corrects your specific headphones **and** simulates a 7.1 room simultaneously with zero additional CPU overhead.

## 2. Component Sources

### Spatial Audio (The Room)
* **Source:** [SADIE II Project (University of York)](https://www.york.ac.uk/sadie-project/database.html)
* **Direct File Access:** [SADIE Airtable Repository](https://airtable.com/appayGNkn3nSuXkaz/shruimhjdSakUPg2m/tbloLjoZKWJDnLtTc)
* **Target File:** `SADIE_D02.wav` (Subject D2 - KEMAR Mannequin)
* **License:** Apache License, Version 2.0.

### Frequency Correction (The Headphones)
* **Source:** [AutoEQ.app](https://autoeq.app/)
* **Targets:** Beyerdynamic DT 990 Pro (250 Ohm) and Sennheiser IE200.
* **Logic:** Profiles were generated to reach a neutral Harman target, taming the "Beyer Peak" and refining the IE200's response.

### Direct Convolution (Pure Stereo)
* **Source:** [AutoEq Repository (GitHub)](https://github.com/jaakkopasanen/AutoEq/tree/master/results)
* **Application:** Used for the **"Stereo EQ - Beyerdynamic DT 990 Convolution"** module. 
* **Logic:** For pure music listening without spatial simulation, I use the impulse response `.wav` files directly from the repository. Specifically, I use the `worn` pad variation for the DT 990 to accurately reflect the acoustic changes that occur as the headphones age.

## 3. The "Baking" Recipe (FFmpeg)

To keep PipeWire stable and lightweight, we use `ffmpeg` to apply the filters directly to the HRTF impulse. 

### For Beyerdynamic DT 990 Pro (250 Ohm)
```bash
ffmpeg -i SADIE_D02.wav -af "
volume=-5.23dB,
lowshelf=f=105:width_type=q:width=0.70:g=5.7,
equalizer=f=82.6:width_type=q:width=0.67:g=-4.5,
equalizer=f=200.8:width_type=q:width=2.44:g=-1.1,
equalizer=f=357.0:width_type=q:width=3.56:g=0.7,
equalizer=f=630.6:width_type=q:width=1.25:g=2.0,
equalizer=f=1038.8:width_type=q:width=2.31:g=-1.4,
equalizer=f=2254.9:width_type=q:width=2.37:g=1.7,
equalizer=f=4629.2:width_type=q:width=4.14:g=4.7,
equalizer=f=6291.1:width_type=q:width=4.64:g=-2.4,
highshelf=f=10000:width_type=q:width=0.70:g=-5.2,
aformat=sample_fmts=fltp
" -c:a pcm_f32le sadie_DT990.wav
```

### For Sennheiser IE200
```bash
ffmpeg -i SADIE_D02.wav -af "
volume=-4.1dB,
lowshelf=f=105:width_type=q:width=0.70:g=0.6,
equalizer=f=28.4:width_type=q:width=1.94:g=-0.3,
equalizer=f=70.9:width_type=q:width=1.29:g=0.9,
equalizer=f=157:width_type=q:width=0.95:g=-1.0,
equalizer=f=268:width_type=q:width=2.24:g=-0.5,
equalizer=f=731.6:width_type=q:width=1.62:g=0.9,
equalizer=f=1473.6:width_type=q:width=1.44:g=-2.1,
equalizer=f=3220.8:width_type=q:width=2.51:g=1.3,
equalizer=f=4566.5:width_type=q:width=1.75:g=4.0,
highshelf=f=10000:width_type=q:width=0.70:g=-6.2,
aformat=sample_fmts=fltp
" -c:a pcm_f32le sadie_IE200.wav
```

## 4. Implementation in PipeWire
For a convenient setup, I have uploaded a sample **`context.modules`** in this repository. 

**Steps to use:**
1. Generate your `.wav` files using the commands above.
2. Place them in your PipeWire configuration folder.
3. Reference the file paths in the `convolver` section of the uploaded `context.modules`.
4. Restart the service: `systemctl --user restart pipewire`.

## 5. Why use this?
* **Zero Performance Hit:** Lower CPU usage than running EQ and Convolver separately.
* **Rock Solid Stability:** Prevents "stalling" or mono-fallback issues in PipeWire.
* **Transparent Audio:** Eliminates phase-shifting artifacts found in many software virtualizers.

---
*SADIE II Database is Copyright © 2018 University of York. Licensed under the Apache License, Version 2.0. Attribution to Cal Armstrong, Lewis Thresh, and Gavin Kearney.*
