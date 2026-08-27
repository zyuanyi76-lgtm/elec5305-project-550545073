# STFT-Based Speech Noise Reduction

## Evaluation and Improvement of Spectral Subtraction

**ELEC5305 Acoustics, Speech and Signal Processing**

**Student:** Yuanyi Zhang
**SID:** 550545073
**GitHub Username:** zyuanyi76-lgtm

## Project Overview

Background noise can reduce the intelligibility and quality of recorded speech. This project investigates speech noise reduction using Short-Time Fourier Transform (STFT)-based spectral subtraction.

The project will first implement a basic spectral subtraction algorithm as a baseline. The baseline system will then be evaluated under controlled noisy conditions to identify its strengths and limitations.

Based on the experimental results, an improved spectral subtraction method will be developed to address problems such as residual noise, speech distortion, and musical-noise artefacts.

The final project will compare the baseline and improved implementations under the same experimental conditions.

## Research Question

**How effectively can basic spectral subtraction reduce speech noise, and can a modified spectral subtraction method reduce processing artefacts while maintaining or improving speech-enhancement performance?**

## Project Structure

The planned investigation follows an iterative signal-processing workflow:

Clean Speech
↓
Add Background Noise
↓
STFT
↓
Basic Spectral Subtraction
↓
Inverse STFT and Overlap-Add
↓
Baseline Evaluation
↓
Identify Shortcomings
↓
Improved Spectral Subtraction
↓
Re-evaluation
↓
Baseline vs Improved Comparison

## Baseline Method

The baseline system will:

* divide noisy speech into overlapping frames;
* apply a Hann window;
* calculate the STFT;
* estimate the background-noise spectrum;
* subtract the estimated noise magnitude from the noisy speech spectrum; and
* reconstruct the enhanced speech using inverse STFT and overlap-add.

## Planned Improvement

The improved implementation will investigate:

* an over-subtraction factor to control the strength of noise reduction; and
* a spectral floor to prevent excessive attenuation of individual frequency components.

These modifications will be investigated as possible methods for reducing musical-noise artefacts and speech distortion.

## Experimental Evaluation

The baseline and improved systems will be tested under the same conditions.

Planned evaluation methods include:

* input SNR;
* output SNR;
* SNR improvement;
* waveform comparison;
* spectrogram comparison; and
* listening-based qualitative analysis.

Several input SNR levels, such as 0 dB, 5 dB, and 10 dB, will be investigated.

## Expected Outputs

The project is expected to produce:

* MATLAB source code;
* a basic spectral subtraction implementation;
* an improved spectral subtraction implementation;
* clean and noisy speech examples;
* baseline and improved enhanced-speech examples;
* waveform and spectrogram visualisations;
* quantitative SNR comparisons;
* analysis of the limitations of both implementations;
* a final project report; and
* a video demonstration of the signal-processing code.
