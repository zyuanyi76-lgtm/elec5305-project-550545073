Beyond SNR: Understanding the Artefacts and Limits of Spectral Subtraction
ELEC5305 — Acoustics, Speech and Signal Processing
Student: Yuanyi Zhang
Student ID: 550545073
Implementation: MATLAB R2024a
Project overview
This project investigates the limitations of short-time Fourier transform (STFT)-based spectral subtraction for speech enhancement. In particular, it asks whether stronger noise suppression produces better results when residual noise, speech distortion, intelligibility, and phase are considered together.

A basic spectral-subtraction method is compared with an over-subtraction/spectral-floor variant. Experiments also include a clean-phase oracle diagnostic and MATLAB's pretrained enhanceSpeech function as an external comparison. The MATLAB pretrained model is not identified here as MP-SENet or as a verified explicit phase-enhancement architecture.
Research questions
1. How do the over-subtraction factor (alpha) and spectral floor (beta) affect reference-based SNR improvement and short-time objective intelligibility (STOI)?
2. How much additional residual-noise attenuation is obtained at the cost of desired-speech distortion?
3. What changes when an estimated magnitude spectrum is reconstructed with oracle clean phase instead of noisy phase?
4. How do the classical approaches compare with the pretrained MATLAB enhanceSpeech reference on the same held-out test mixtures?
Dataset and experimental design
Item	Setting
Clean speech	12 utterances selected from the LibriSpeech test-clean corpus
Speakers	6 total: 2 development speakers and 4 separate test speakers
Speech duration	Approximately 3–8 seconds per utterance
Sample format	16 kHz, mono
Noise types	Generated white noise; one real, time-varying environmental-noise recording
Input SNR	0, 5, and 10 dB
Development set	4 utterances × 2 noises × 3 SNRs = 24 mixtures
Held-out test set	8 utterances × 2 noises × 3 SNRs = 48 mixtures
Total	72 mixtures


Speakers are disjoint between development and test sets. Parameters were selected on development mixtures and fixed before held-out evaluation. The 48 test mixtures are derived from eight underlying utterances, so they should not be treated as 48 independent speakers or utterances.

The environmental recording was converted to 16 kHz mono. It is not included for public redistribution unless its source and reuse rights can be confirmed. Using a different recording will change the numerical outcomes.
Methods
Basic spectral subtraction
Let Y(m,k) be the noisy STFT and Nhat(k) the estimated noise magnitude spectrum. The basic magnitude estimate is

|S_hat(m,k)| = max(|Y(m,k)| - |Nhat(k)|, 0).

The phase of the noisy mixture is retained for inverse STFT reconstruction.
Modified spectral subtraction
The tested gain-floor variant is

G(m,k) = min(1, max(1 - alpha * |Nhat(k)| / max(|Y(m,k)|, eps), beta))

and S_hat(m,k) = G(m,k) * Y(m,k).
- alpha: over-subtraction factor, evaluated at 1, 1.5, 2, 2.5, 3.
- beta: minimum spectral gain, evaluated at 0, 0.01, 0.03, 0.05.
- Noise estimation: initial 0.5 s noise-only prefix.
- STFT: 512-sample Hann window, 256-sample hop (50% overlap), 512-point FFT, 16 kHz sampling.
There are 20 alpha–beta configurations, evaluated on 24 development mixtures (480 parameter evaluations). The selected configurations were not retuned using the test set.
Oracle phase diagnostic
The estimated enhanced magnitude is held fixed while its phase is replaced by the phase of the corresponding clean reference STFT. This uses information unavailable at deployment and is only a diagnostic comparison, not a practical enhancement algorithm or a guaranteed mathematical upper bound.
Pretrained reference
The MATLAB Audio Toolbox enhanceSpeech function is evaluated on the same 48 held-out mixtures. The pretrained model is used as supplied, without training on or tuning against these samples. Its results should not be described as an MP-SENet implementation unless the actual architecture has been independently verified.
Evaluation metrics
Reference-based reconstruction SNR is computed from clean speech s and enhanced speech s_hat:

SNR_out = 10 * log10(sum(s.^2) / sum((s_hat - s).^2)).

SNR improvement is SNR_out - SNR_in. This definition penalizes residual noise and changes to the desired speech waveform; it should not be interpreted as a pure residual-noise power measure.

STOI is evaluated using MATLAB stoi(enhanced, clean, fs). Spectrogram inspection and matched-level audio examples provide qualitative complementary evidence. STOI is an intelligibility predictor, not a direct listening-quality or naturalness score.
Results
Held-out test set: 48 matched noisy mixtures
Method	alpha	beta	Mean SNR improvement (dB)	Mean output STOI
Basic spectral subtraction	1.0	0.00	4.8472	0.80834
SNR-focused spectral subtraction	1.5	0.05	5.5096	0.80541
STOI-focused spectral subtraction	1.0	0.05	4.8330	0.80886
Aggressive diagnostic	3.0	0.03	4.0528	0.78630
MATLAB pretrained enhanceSpeech	—	—	-1.3739	0.82187


Relative to Basic, the SNR-focused method increases mean reconstruction-SNR improvement by approximately 0.6624 dB, but reduces mean STOI by approximately 0.00293. The STOI-focused configuration offers only a very small mean STOI difference over Basic (approximately +0.00052) and should not be presented as a meaningful or statistically established intelligibility improvement.

The pretrained function achieves the highest mean STOI in this comparison, but a much lower reference-based reconstruction-SNR score. On the development set, an input–output cross-correlation check found zero lag for 24/24 files; oracle amplitude rescaling changed mean reconstruction SNR by only about 0.34 dB. The model comparison therefore illustrates disagreement among evaluation metrics, not a universal ranking of speech-enhancement quality.
Noise suppression versus speech distortion
At a fixed beta = 0.03, increasing alpha from 1 to 3 increased mean residual-noise attenuation from 7.66 to 18.07 dB, while the measured desired-speech distortion energy increased from 4.88% to 19.98% on development mixtures. The distortion percentage is a signal-energy ratio, not a subjective distortion percentage.
Oracle phase
For the Basic method on 48 held-out mixtures, replacing noisy phase with oracle clean phase produced a mean +1.8805 dB change in reference-based output SNR and +0.02071 in STOI. This supports investigating phase retention as a reconstruction limitation, within the scope and caveats of the oracle experiment.
Figures

Additional figures are in [`results/figures/`](results/figures/) and detailed CSV tables in [`results/metrics/`](results/metrics/).
Audio demonstrations
Selected listening examples are stored in [`results/audio/`](results/audio/) where redistribution is permitted. Relevant comparisons include clean/noisy speech, basic and modified spectral subtraction, aggressive attenuation, oracle phase, and pretrained enhancement. Compare files at consistent playback levels; files created by different scripts may use different overall gains.

If recordings derived from environmental noise cannot legally be published, the corresponding files are retained locally and are not publicly distributed.
Repository structure
code/
  preprocessing/     # Data selection, preparation and mixture generation
  enhancement/       # STFT, algorithms, evaluation and audits
results/
  figures/           # Plots used in analysis
  metrics/           # Detailed and aggregated evaluation CSV files
  audio/             # Selected listening demonstrations, if permitted
data/                # Local input data and generated mixtures (not committed)
external/            # Downloaded model files (not committed)
Requirements and reproduction
- MATLAB R2024a (the version used for this project).
- Audio Toolbox for stoi and enhanceSpeech; additional signal-processing functions may require Signal Processing Toolbox.
- The LibriSpeech test-clean speech corpus and a legally usable environmental-noise recording.
- The official MATLAB pretrained enhanceSpeech model files for the pretrained baseline.
Model weights: MathWorks enhanceSpeech model ZIP. Extract locally under external/enhanceSpeechModel/ and add its directories to the MATLAB search path. Do not commit model weights to this repository.

Suggested execution order (after obtaining the required inputs and keeping the directory structure above):
1. code/preprocessing/select_clean_utterances.m
2. code/preprocessing/verify_clean_dataset.m
3. code/preprocessing/prepare_environmental_noise.m
4. code/preprocessing/check_environmental_noise.m
5. code/preprocessing/generate_mixtures.m
6. code/enhancement/validate_stft_istft.m
7. code/enhancement/demo_basic_spectral_subtraction.m
8. code/enhancement/run_alpha_beta_sweep.m
9. code/enhancement/run_stoi_evaluation.m
10. code/enhancement/analyse_speech_noise_tradeoff.m
11. code/enhancement/run_final_test_evaluation.m
12. code/enhancement/analyse_oracle_phase.m
13. code/enhancement/run_pretrained_model_comparison.m
14. code/enhancement/validate_pretrained_model_outputs.m
15. code/enhancement/audit_final_results.m
Use the additional demo_*.m and analyse_final_spectrograms.m scripts for listening examples and visualizations. The project-root discovery in the current scripts assumes they remain inside code/preprocessing/ or code/enhancement/. Add the code/enhancement/ directory to the MATLAB path as needed for shared functions.

Reproducibility limitation: The public repository includes code and recorded metrics but does not include the original large speech corpus, the environmental-noise recording unless redistribution is authorized, or pretrained model weights. Reproducing the exact published numbers requires the same underlying files and mixture-generation settings; substituting an environmental recording may reproduce the procedure but not identical scores. The scripts and saved outputs have been checked for internal consistency, but the entire workflow has not been independently rerun on a clean second machine.
Main conclusions and limitations
- More aggressive spectral subtraction reduces residual noise but can also erase desired-speech components.
- A parameter setting with higher reconstruction SNR need not have higher STOI.
- Oracle clean phase improves evaluation metrics in this controlled diagnostic, but it is not available to a real enhancement system.
- The pretrained MATLAB reference yields the highest mean STOI here, while reconstruction-SNR scores favour some classical configurations.
- The study is limited by 12 utterances, six speakers, one environmental-noise recording, and a small predefined parameter grid. Conclusions should not be generalized to all noise environments or listeners.
References and documentation
1. S. F. Boll, “Suppression of acoustic noise in speech using spectral subtraction,” IEEE Transactions on Acoustics, Speech, and Signal Processing, 1979.
2. C. H. Taal, R. C. Hendriks, R. Heusdens, and J. Jensen, “An algorithm for intelligibility prediction of time-frequency weighted noisy speech,” IEEE Transactions on Audio, Speech, and Language Processing, 2011.
3. V. Panayotov, G. Chen, D. Povey, and S. Khudanpur, “LibriSpeech: An ASR corpus based on public domain audio books,” ICASSP, 2015. Corpus.
4. MathWorks documentation: enhanceSpeech.
5. MathWorks documentation: stoi.
