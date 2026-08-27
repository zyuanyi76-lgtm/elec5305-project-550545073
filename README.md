# STFT-Based Speech Noise Reduction

## Evaluation and Modification of Spectral Subtraction

**ELEC5305 Acoustics, Speech and Signal Processing**

**Student:** Yuanyi Zhang  
**SID:** 550545073  
**GitHub Username:** zyuanyi76-lgtm  

## Project Overview

Background noise can reduce the intelligibility and quality of recorded speech. This project investigates STFT-based spectral subtraction for speech noise reduction.

A basic spectral subtraction algorithm will first be implemented as a baseline system. Its performance will then be evaluated under controlled noisy conditions. Based on the observed shortcomings, a modified spectral subtraction method using an over-subtraction factor and a spectral floor will be developed and evaluated under the same test conditions.

## Research Question

Across white and non-stationary environmental noise at input SNRs of 0, 5, and 10 dB, how do basic and modified spectral subtraction compare in SNR improvement and STOI, and what trade-off between residual noise and speech distortion is introduced by the over-subtraction factor and spectral floor?

## Experimental Setup

- Sampling rate: 16 kHz
- Audio format: mono
- Clean speech: 12 English utterances from 2 speakers
- Speech source: LibriSpeech test-clean corpus
- Noise types:
  - White Gaussian noise
  - Non-stationary environmental noise from MUSAN
- Input SNR levels:
  - 0 dB
  - 5 dB
  - 10 dB
- Total mixtures: 72

The dataset will be divided into:

- Development set: 4 utterances, producing 24 mixtures
- Test set: 8 utterances, producing 48 mixtures

The development set will be used to select the over-subtraction and spectral-floor parameters. Final evaluation will be performed only on the test set.

## Signal Processing Method

The main STFT parameters will be fixed as:

- Hann window: 512 samples (32 ms)
- Hop size: 256 samples
- Overlap: 50%
- FFT size: 512

The processing workflow is:

Clean Speech  
↓  
Add Noise  
↓  
STFT  
↓  
Basic Spectral Subtraction  
↓  
Inverse STFT and Overlap-Add  
↓  
Baseline Evaluation  
↓  
Modified Spectral Subtraction  
↓  
Re-evaluation  
↓  
Baseline vs Modified Comparison

## Baseline Method

The baseline magnitude estimate is:

|S_base(m,k)| = max(|Y(m,k)| - |N_hat(k)|, 0)

The noise spectrum will be estimated from a 0.5-second noise-only segment placed before the speech.

The noisy phase will be retained during signal reconstruction.

## Modified Method

The modified method is:

|S_mod(m,k)| = max(|Y(m,k)| - alpha|N_hat(k)|, beta|N_hat(k)|)

where:

- alpha controls over-subtraction
- beta controls the spectral floor

Only alpha and beta will be tuned during development.

## Evaluation

The two formal evaluation metrics are:

- SNR improvement
- Short-Time Objective Intelligibility (STOI)

Additional analysis will include:

- Spectrogram comparison
- Waveform comparison
- Informal listening comparison
- Residual-noise analysis
- Musical-noise and speech-distortion analysis

## Expected Outputs

The project will produce:

- MATLAB source code
- Baseline spectral subtraction implementation
- Modified spectral subtraction implementation
- Clean, noisy, and enhanced speech samples
- SNR and STOI results
- Waveform and spectrogram comparisons
- Final project report
- Video demonstration
- GitHub project documentation
