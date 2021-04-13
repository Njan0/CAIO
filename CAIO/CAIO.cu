#include "CAIO.cuh"

#include <cuda_runtime.h>
#include <device_launch_parameters.h>

using State = CAIO::State;

std::array<unsigned char, 16> generateStateCount() {
    std::array<unsigned char, 16> result;
    for (int i = 0; i < 16; ++i) {
        // count bits which are one
        int ones = 0;
        for (int bit = 0; bit < 4; ++bit) {
            ones += i >> bit & 1;
        }

        result[i] = ones;
    }

    return result;
}
const std::array<unsigned char, 16> stateCount = generateStateCount();

std::array<unsigned char, 16> generateStateColor() {
    std::array<unsigned char, 16> result;
    for (int i = 0; i < 16; ++i) {
        result[i] = stateCount[i] == 4 ? 255 : stateCount[i] * 64;
    }

    return result;
}
const std::array<unsigned char, 16> stateColor = generateStateColor();

__host__ __device__ State operator&(const State& lhs, const State& rhs)
{
    return static_cast<State>(static_cast<unsigned char>(lhs) & static_cast<unsigned char>(rhs));
}

__host__ __device__ State operator|(const State& lhs, const State& rhs)
{
    return static_cast<State>(static_cast<unsigned char>(lhs) | static_cast<unsigned char>(rhs));
}

__host__ __device__ State& operator|=(State& lhs, const State& rhs)
{
    return lhs = static_cast<State>(static_cast<unsigned char>(lhs) | static_cast<unsigned char>(rhs));
}

CAIO::CAIO(int width, int height, bool reflectiveBoundary, std::array<State, 16> updateRules, const std::function<State(int x, int y)>& states) : width(width), height(height), reflective(reflectiveBoundary), size(static_cast<size_t>(width) * height), cells(), updateRules(updateRules) {
    for (auto rule : updateRules) {
        if (static_cast<unsigned char>(rule) >= 16) {
            throw "Invalid update rule";
        }
    }

    // initalize cells
    cells.reserve(size);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            auto state = states(x, y);
            cells.emplace_back(state);
            drawBuffer.emplace_back(stateColor[static_cast<char>(state)]);
        }
    }
}

int CAIO::getIndex(int x, int y) {
    return x + y * width;
}

bool CAIO::checkState(int x, int y, State state) {
    return checkState(getIndex(x, y), state);
}

bool CAIO::checkState(int i, State state) {
    return (cells[i] & state) == state;
}

void CAIO::update() {
    auto inputs = std::make_unique<State[]>(size);

    if (reflective) {
        // loop for reflective boundary
        int i = 0;
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                State state = State::Empty;

                if (x > 0) {
                    // check cell to the left
                    if (checkState(x - 1, y, State::Right))
                        state |= State::Left;
                }
                else {
                    // left boundary
                    state |= cells[i] & State::Left;
                }

                if (y > 0) {
                    // check cell above
                    if (checkState(x, y - 1, State::Down))
                        state |= State::Up;
                }
                else {
                    // upper boundary
                    state |= cells[i] & State::Up;
                }

                if (x < width - 1) {
                    // check cell to the right
                    if (checkState(x + 1, y, State::Left))
                        state |= State::Right;
                }
                else {
                    // right boundary
                    state |= cells[i] & State::Right;
                }

                if (y < height - 1) {
                    // check cell below
                    if (checkState(x, y + 1, State::Up))
                        state |= State::Down;
                }
                else {
                    // lower boundary
                    state |= cells[i] & State::Down;
                }

                inputs[i] = state;
                ++i;
            }
        }
    }
    else {
        // loop for periodic boundary
        int i = 0;
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                State state = State::Empty;

                // check cell to the left
                int left = x > 0 ? x - 1 : width - 1;
                if (checkState(left, y, State::Right))
                    state |= State::Left;

                // check cell above
                int up = y > 0 ? y - 1 : height - 1;
                if (checkState(x, up, State::Down))
                    state |= State::Up;

                // check cell to the right
                int right = x < width - 1 ? x + 1 : 0;
                if (checkState(right, y, State::Left))
                    state |= State::Right;

                // check cell below
                int down = y < height - 1 ? y + 1 : 0;
                if (checkState(x, down, State::Up))
                    state |= State::Down;

                inputs[i] = state;
                ++i;
            }
        }
    }

    // apply update rules
    for (int i = 0; i < size; ++i) {
        cells[i] = updateRules[static_cast<unsigned char>(inputs[i])];
        drawBuffer[i] = stateColor[static_cast<char>(cells[i])];
    }
}

void CAIO::draw(std::ostream& out) {
    out.write(drawBuffer.data(), size);
}

__device__ inline int getIndex(int x, int y, int width) {
    return x + y * width;
}

__device__ inline bool checkState(State* cells, int x, int y, int width, State state) {
    return (cells[getIndex(x, y, width)] & state) == state;
}

__global__ void updateKernel(State* cells, int width, int height, bool reflectiveBoundary, State* updateRules, State* out, char* colorRules, char* outColor) {
    unsigned int x = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height)
        return;

    State input = State::Empty;
    int i = getIndex(x, y, width);

    if (reflectiveBoundary) {
        if (x > 0) {
            // check cell to the left
            if (checkState(cells, x - 1, y, width, State::Right))
                input |= State::Left;
        }
        else {
            // left boundary
            input |= cells[i] & State::Left;
        }

        if (y > 0) {
            // check cell above
            if (checkState(cells, x, y - 1, width, State::Down))
                input |= State::Up;
        }
        else {
            // upper boundary
            input |= cells[i] & State::Up;
        }

        if (x < width - 1) {
            // check cell to the right
            if (checkState(cells, x + 1, y, width, State::Left))
                input |= State::Right;
        }
        else {
            // right boundary
            input |= cells[i] & State::Right;
        }

        if (y < height - 1) {
            // check cell below
            if (checkState(cells, x, y + 1, width, State::Up))
                input |= State::Down;
        }
        else {
            // lower boundary
            input |= cells[i] & State::Down;
        }
    }
    else {
        // check cell to the left
        int left = x > 0 ? x - 1 : width - 1;
        if (checkState(cells, left, y, width, State::Right))
            input |= State::Left;

        // check cell above
        int up = y > 0 ? y - 1 : height - 1;
        if (checkState(cells, x, up, width, State::Down))
            input |= State::Up;

        // check cell to the right
        int right = x < width - 1 ? x + 1 : 0;
        if (checkState(cells, right, y, width, State::Left))
            input |= State::Right;

        // check cell below
        int down = y < height - 1 ? y + 1 : 0;
        if (checkState(cells, x, down, width, State::Up))
            input |= State::Down;
    }

    // apply update rule
    out[i] = updateRules[static_cast<unsigned char>(input)];
    outColor[i] = colorRules[static_cast<unsigned char>(out[i])];
}

/**
 * Calculate the smallest integer which is
 * greater or equal the quotient of the
 * two given positive integers.
 *
 * @param dividend
 * @param divisor
 * @return ceiling(dividend / divisor)
 */
int divideRoundUp(unsigned int dividend, unsigned int divisor) {
    return 1 + ((dividend - 1) / divisor);
}

void CAIO::updateCuda(unsigned int blockWidth, unsigned int blockHeight) {
    dim3 blocks(divideRoundUp(width, blockWidth), divideRoundUp(height, blockHeight));
    dim3 threadsPerBlock(blockWidth, blockHeight);

    // input
    State* cellsDevice;
    State* updateRulesDevice;
    char* colorRulesDevice;

    // output
    State* out;
    char* outColor;

    // memory sizes
    auto dataMemorySize = sizeof(State) * size;
    auto ruleMemorySize = sizeof(State) * 16;
    auto colorMemorySize = sizeof(char) * size;
    auto colorRuleMemorySize = sizeof(char) * 16;

    // copy cells to device
    cudaMalloc(&cellsDevice, dataMemorySize);
    cudaMemcpy(cellsDevice, cells.data(), dataMemorySize, cudaMemcpyHostToDevice);

    // copy rules to device
    cudaMalloc(&updateRulesDevice, ruleMemorySize);
    cudaMemcpy(updateRulesDevice, updateRules.data(), ruleMemorySize, cudaMemcpyHostToDevice);

    // copy color rules to device
    cudaMalloc(&colorRulesDevice, colorRuleMemorySize);
    cudaMemcpy(colorRulesDevice, stateColor.data(), colorRuleMemorySize, cudaMemcpyHostToDevice);

    // allocate memory for result
    cudaMalloc(&out, dataMemorySize);
    cudaMalloc(&outColor, colorMemorySize);

    // run kernel 
    updateKernel<<<blocks, threadsPerBlock>>>(cellsDevice, width, height, reflective, updateRulesDevice, out, colorRulesDevice, outColor);

    // copy result to host
    cudaMemcpy(cells.data(), out, dataMemorySize, cudaMemcpyDeviceToHost);
    cudaMemcpy(drawBuffer.data(), outColor, colorMemorySize, cudaMemcpyDeviceToHost);

    // free memory on device
    cudaFree(cellsDevice);
    cudaFree(updateRulesDevice);
    cudaFree(colorRulesDevice);
    cudaFree(out);
    cudaFree(outColor);
}