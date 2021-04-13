#include "CAIO.cuh"
#include <random>

int main() {
    int width = 1024;
    int height = 1024;
    int iterations = 1000;

    // randomly generate each space while leaving a circular spot empty
    auto rnd = std::mt19937(std::random_device()());
    auto randomState = [&](int x, int y) -> CAIO::State {
        // check if in empty spot
        int dX = width / 4 - x;
        int dY = height / 4 - y;
        int avg = (width + height) / 2;
        if (dX * dX + dY * dY < avg*avg / 32)
            return CAIO::State::Empty;

        // generate random state
        std::uniform_int_distribution<int> distribution(0, 15);
        int state = distribution(rnd);
        return static_cast<CAIO::State>(state);
    };

    // HPP model
    std::array<CAIO::State, 16> updateRules = {
        CAIO::State::Empty, // Empty
        CAIO::State::Down, // Up
        CAIO::State::Left, // Right
        CAIO::State::Down | CAIO::State::Left, // Up Right
        CAIO::State::Up, // Down
        CAIO::State::Right | CAIO::State::Left, // Up Down
        CAIO::State::Up | CAIO::State::Left, // Right Down
        CAIO::State::Up | CAIO::State::Down | CAIO::State::Left, // Up Right Down
        CAIO::State::Right, // Left
        CAIO::State::Right | CAIO::State::Down, // Up Left
        CAIO::State::Up | CAIO::State::Down, // Right Left
        CAIO::State::Right | CAIO::State::Down | CAIO::State::Left, // Up Right Left
        CAIO::State::Up | CAIO::State::Right, // Down Left
        CAIO::State::Up | CAIO::State::Right | CAIO::State::Down, // Up Down Left
        CAIO::State::Up | CAIO::State::Right | CAIO::State::Left, // Right Down Left
        CAIO::State::Up | CAIO::State::Right | CAIO::State::Down | CAIO::State::Left, // Up Right Down Left
    };

    auto caio = CAIO(width, height, true, updateRules, randomState);

    caio.draw(std::cout);
    for (int i = 0; i < iterations; ++i) {
        //caio.update();
        caio.updateCuda(16, 16);
        caio.draw(std::cout);
    }

    return 0;
}