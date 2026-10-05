function result = basic_spectral_subtraction( ...
    fullNoisy, fs, prefixDuration, ...
    winLength, hopSize, nfft)

%% =========================================================
% Basic spectral subtraction
%
% |S_hat| = max(|Y| - |N_hat|, 0)
%
% Reconstruction uses noisy phase.
%% =========================================================

fullNoisy = fullNoisy(:);

%% STFT of complete noisy recording

[Y, stftInfo] = stft_analysis_custom( ...
    fullNoisy, ...
    fs, ...
    winLength, ...
    hopSize, ...
    nfft);

magnitudeY = abs(Y);
phaseY = angle(Y);

%% =========================================================
% Estimate noise spectrum from the 0.5 s noise-only prefix
%% =========================================================

prefixSamples = round(prefixDuration * fs);

if prefixSamples > length(fullNoisy)
    error("Noise-only prefix is longer than signal.");
end

noisePrefix = fullNoisy(1:prefixSamples);

window = hann(winLength, 'periodic');

numNoiseFrames = ...
    floor((length(noisePrefix)-winLength)/hopSize) + 1;

if numNoiseFrames < 1
    error("Noise-only prefix is too short.");
end

noiseMagnitudeFrames = zeros(nfft, numNoiseFrames);

for m = 1:numNoiseFrames

    idx1 = (m-1)*hopSize + 1;
    idx2 = idx1 + winLength - 1;

    frame = noisePrefix(idx1:idx2);

    frame = frame .* window;

    N = fft(frame, nfft);

    noiseMagnitudeFrames(:,m) = abs(N);
end

%% Average estimated noise magnitude

noiseMagnitude = mean( ...
    noiseMagnitudeFrames, 2);

%% =========================================================
% Basic spectral subtraction
%% =========================================================

estimatedMagnitude = ...
    max( ...
        magnitudeY - noiseMagnitude, ...
        0);

%% Gain matrix
%
% Save this now because it will be useful later for
% speech/noise decomposition.

gain = estimatedMagnitude ./ ...
    (magnitudeY + eps);

%% Reconstruct complex spectrum using noisy phase

S_hat = ...
    estimatedMagnitude .* exp(1j*phaseY);

%% ISTFT

enhancedFull = ...
    stft_synthesis_custom( ...
        S_hat, ...
        stftInfo);

%% Package results

result.enhancedFull = enhancedFull;

result.gain = gain;

result.noiseMagnitude = noiseMagnitude;

result.estimatedMagnitude = estimatedMagnitude;

result.inputSTFT = Y;

result.outputSTFT = S_hat;

result.stftInfo = stftInfo;

end