var source = new EventSource('/events');
source.addEventListener('message', function(event) {
    var amp;
    var freq;
    [amp, freq] = event.data.split(",");
    play(parseFloat(amp), parseFloat(freq));
});

var context = new AudioContext();
var gain = context.createGain();
var oscillator = context.createOscillator();

oscillator.connect(gain);
oscillator.type = 'square';
oscillator.start();
gain.gain.value = 0;
gain.connect(context.destination);

function voldown() {
    var new_volume = gain.gain.value - 0.01;
    gain.gain.value = new_volume >= 0 ? new_volume : 0;
}

setInterval(voldown, 10);

function play(amplitude, frequency) {
    console.log(frequency);
    oscillator.frequency.value = frequency;
    gain.gain.value = amplitude;
}
