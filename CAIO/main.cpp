#include "CAIO.cuh"
#include <random>
#include <string>

int main(int argc, char* argv[]) {
    int width = 512;
    int height = 512;
    int iterations = 500;
    int example = 1;

    // get width
    if (argc > 1) {
        try {
            width = std::stoi(argv[1]);
        }
        catch (std::exception) {
            width = 0;
        }

        if (width <= 0) {
            std::cerr << "Invalid width!";
            return 1;
        }
    }

    // get height
    if (argc > 2) {
        try {
            height = std::stoi(argv[2]);
        }
        catch (std::exception) {
            height = 0;
        }

        if (height <= 0) {
            std::cerr << "Invalid height!";
            return 1;
        }
    }

    // get iteration number
    if (argc > 3) {
        try {
            iterations = std::stoi(argv[3]);
        }
        catch (std::exception) {
            iterations = -1;
        }

        if (iterations < 0) {
            std::cerr << "Invalid number of iterations!";
            return 1;
        }
    }

    // get example number
    if (argc > 4) {
        try {
            example = std::stoi(argv[4]);
        }
        catch (std::exception) {
            example = 1;
        }
    }

    std::function<CAIO::State(int x, int y)> initStates;
    std::array<CAIO::State, 16> updateRules;

    switch (example) {
    case 2: { // Example 2
        // set state of boundary cells to output in all directions
        initStates = [&](int x, int y) -> CAIO::State {
            if (x == 0  || x == width - 1 || y == 0 || y == height - 1)
                return CAIO::State::Up | CAIO::State::Right | CAIO::State::Down | CAIO::State::Left;

            return CAIO::State::Empty;
        };

        // Receiving no or four signals leads to no output
        updateRules[0] = updateRules[15] = CAIO::State::Empty;

        // Otherwise signal in all directions
        for (int i = 1; i < 15; ++i)
        {
            updateRules[i] = CAIO::State::Up | CAIO::State::Right | CAIO::State::Down | CAIO::State::Left;
        }
        break;
    }
    default: { // Example 1
        // randomly set state of each cell while leaving a circular spot empty
        auto rnd = std::mt19937(std::random_device()());
        initStates = [&](int x, int y) -> CAIO::State {
            // check if in empty spot
            int dX = width / 4 - x;
            int dY = height / 4 - y;
            int avg = (width + height) / 2;
            if (dX * dX + dY * dY < avg * avg / 32)
                return CAIO::State::Empty;

            // generate random state
            std::uniform_int_distribution<int> distribution(0, 15);
            int state = distribution(rnd);
            return static_cast<CAIO::State>(state);
        };

        // HPP model
        updateRules = {
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
        break;
    }
    }

    auto caio = CAIO(width, height, true, updateRules, initStates);

    caio.draw(std::cout);
    for (int i = 0; i < iterations; ++i) {
        //caio.update();
        caio.updateCuda(16, 16);
        caio.draw(std::cout);
    }

    return 0;
}