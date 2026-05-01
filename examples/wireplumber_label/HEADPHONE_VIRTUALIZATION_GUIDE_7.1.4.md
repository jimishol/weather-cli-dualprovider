# Guide: 7.1.4 Virtual Surround with AutoEq Calibration

This guide explains how to create a custom 7.1.4 Atmos-style HRIR (Head-Related Impulse Response) file, calibrate it for your specific headphones, and integrate it into PipeWire.



## 1. Obtain the HRIR Files
1. Go to the [York SADIE Project Database](https://www.york.ac.uk/sadie-project/database.html).
2. Choose a subject (e.g., Subject 001) and click **Download Subject**.
3. Unzip the file and navigate to the `_HRIR_WAV/sample_rate` subfolder (match this to your PipeWire sample rate, usually 48kHz).

## 2. Generate the 7.1.4 Surround Wav
The following `ffmpeg` command merges the directional stereo files into a single 22-channel file (11 positions × 2 ears). 

**Note:** The LFE (Low Frequency Effects) channel is omitted from HRIR processing as it is omnidirectional and usually handled by the system's crossover.

```bash
ffmpeg \
-i "azi_30,0_ele_0,0.wav" -i "azi_90,0_ele_0,0.wav" -i "azi_150,0_ele_0,0.wav" \
-i "azi_0,0_ele_0,0.wav" -i "azi_330,0_ele_0,0.wav" -i "azi_270,0_ele_0,0.wav" \
-i "azi_210,0_ele_0,0.wav" \
-i "azi_45,0_ele_45,0.wav" -i "azi_315,0_ele_45,0.wav" \
-i "azi_135,0_ele_45,0.wav" -i "azi_225,0_ele_45,0.wav" \
-filter_complex "[0:a][1:a][2:a][3:a][4:a][5:a][6:a][7:a][8:a][9:a][10:a]amerge=inputs=11[a]" \
-map "[a]" -c:a pcm_f32le sadie_atmos_7.1.4.wav
```
**Note:** If you deviate, keep track of the order you list the inputs here; they must match the channel mapping order in your PipeWire module configuration.

## 3. Apply Headphone Correction (AutoEq)
To ensure the spatialization sounds natural, you must neutralize your headphones' frequency response.

1. Find your hardware in the [AutoEq Results folder](https://github.com/jaakkopasanen/AutoEq/tree/master/results).
2. Download the `parametricEQ.txt` file.
3. Convert the filters into an `ffmpeg` command. 

### Example: Beyerdynamic DT 990
```bash
ffmpeg -i sadie_atmos_7.1.4.wav -af "
volume=-5.90dB,
lowshelf=f=105:width_type=q:width=0.70:g=9.2,
equalizer=f=83:width_type=q:width=0.28:g=-5.4,
equalizer=f=3197:width_type=q:width=2.04:g=3.1,
equalizer=f=544.0:width_type=q:width=0.50:g=2.5,
equalizer=f=54:width_type=q:width=0.46:g=-1.6,
equalizer=f=4345:width_type=q:width=6.00:g=1.4,
equalizer=f=1725:width_type=q:width=1.96:g=0.2,
equalizer=f=9776:width_type=q:width=5.96:g=-0.2,
equalizer=f=6345:width_type=q:width=5.42:g=0.9,
highshelf=f=10000:width_type=q:width=0.70:g=-9.4,
aformat=sample_fmts=fltp
" -c:a pcm_f32le sadie_DT990.wav
```

## 4. Configure PipeWire
1. Move your generated file (e.g., `sadie_DT990.wav`) to `~/.config/pipewire/`.
2. Copy the default PipeWire config:
   `cp /usr/share/pipewire/pipewire.conf ~/.config/pipewire/pipewire.conf`
3. Edit `~/.config/pipewire/pipewire.conf` and append the contents of your `context.modules_7.1.4` file into the `context.modules` section.

**Note on File Paths:** While ~/ (the home shortcut) works in many setups, using the full absolute path (e.g., /home/username/.config/pipewire/...) is the most reliable way to ensure PipeWire finds your WAV file without errors.

### Crucial Convolver Notes
*   **Naming Consistency:** Ensure `capture.props` and `playback.props` use the same `node.name` (e.g., `effect_input.DT990`) to ensure the virtual sink maps correctly to the hardware.
*   **Stereo Stability:** For standard stereo modules (if used), `node.always-process = true`. This prevents PipeWire from suspending the node, which often causes activation issues with Bluetooth or hot-plugged devices.

## 5. (Optional) Standalone Stereo EQ
If you only need basic EQ for music without spatialization:
1. Download the 2-channel WAV from AutoEq.
2. Convert it for PipeWire compatibility:
   `ffmpeg -y -i AutoEq_Stereo.wav -ar 48000 -ac 2 -c:a pcm_f32le stereo_correction.wav`
3. Reference this file in a simple `libfilter-chain` module within your `context.modules`.
