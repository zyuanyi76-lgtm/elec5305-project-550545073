# STFT-Based Speech Noise Reduction

## ELEC5305 Acoustic, Speech and Signal Processing

**Student:** Yuanyi Zhang  
**SID:** 550545073  
**GitHub Username:** zyuanyi76-lgtm  

## Project Overview

Background noise can significantly reduce the quality and intelligibility of speech signals. This project investigates speech enhancement using Short-Time Fourier Transform (STFT)-based signal processing techniques.

The project will implement and compare two classical speech noise reduction methods:

1. Spectral Subtraction
2. Wiener Filtering

Both methods will operate in the time-frequency domain. The noisy speech signal will first be transformed using the STFT, processed in the frequency domain, and then reconstructed using the inverse STFT and overlap-add method.

## Project Objectives

The main objectives of this project are:

- To understand and implement STFT-based speech processing.
- To implement spectral subtraction for speech noise reduction.
- To implement Wiener filtering for speech enhancement.
- To compare the performance of the two approaches.
- To evaluate the processed speech using objective metrics and spectrogram analysis.

## Proposed Method

The planned signal-processing workflow is:

Clean Speech  
↓  
Add Background Noise  
↓  
STFT  
↓  
Spectral Subtraction / Wiener Filtering  
↓  
Inverse STFT  
↓  
Enhanced Speech  
↓  
Performance Evaluation

MATLAB will be used as the main implementation platform.

## Evaluation

The performance of the two methods will be compared using:

- Input and output Signal-to-Noise Ratio (SNR)
- SNR improvement
- Waveform comparison
- Spectrogram comparison
- Listening comparison

## Expected Outcomes

The project is expected to produce:

- A MATLAB implementation of spectral subtraction.
- A MATLAB implementation of Wiener filtering.
- Clean, noisy, and enhanced speech samples.
- Waveform and spectrogram visualisations.
- Quantitative comparison of speech enhancement performance.
- Final project report and GitHub documentation.
