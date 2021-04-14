# CAIO
CAIO is a simple cellular automaton. Each cell can signal up to four of its adjacent cells. In the update step each cell checks from which directions it receives signals. Using this information the cells decide which neighbors they will signal in the next step.

## Example
[main.cpp](./CAIO/main.cpp) shows a exemplary use of the model.
```c++
auto caio = CAIO(width, height, true, updateRules, initStates);
caio.draw(std::cout);
for (int i = 0; i < iterations; ++i) {
    caio.updateCuda(16, 16);
    caio.draw(std::cout);
}
```
The output of ```draw()```  is a grayscale image where each pixel is represented by one byte. The brightness of each pixel corresponds to the number of outgoing signals. This output can be piped to a converter of your choice. (e.g. ffmpeg)
```
CAIO 512 512 500 | ffmpeg -y -f rawvideo -pix_fmt gray -video_size 512x512 -framerate 25 -i - example1.gif
```
![Example GIF 1](./example1.gif) ![Example GIF 2](./example2.gif)