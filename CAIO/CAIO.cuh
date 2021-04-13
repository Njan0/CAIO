#pragma once
#include <array>
#include <iostream>
#include <vector>
#include <functional>

class CAIO {
public:
    enum class State : unsigned char {
        Empty = 0,
        Up = 1 << 0,
        Right = 1 << 1,
        Down = 1 << 2,
        Left = 1 << 3
    };

private:
    const int width;
    const int height;
    const size_t size;
    const bool reflective;
    std::vector<State> cells;
    std::vector<char> drawBuffer;
    std::array<State, 16> updateRules;

public:
    /// <summary>
    /// Constructor
    /// </summary>
    /// <param name="width">width</param>
    /// <param name="height">height</param>
    /// <param name="reflectiveBoundary">true if boundary is reflective otherwise periodic</param>
    /// <param name="updateRules">map the input of given cell to its next state</param>
    /// <param name="states">function to generate initial state for each cell</param>
    CAIO(int width, int height, bool reflectiveBoundary, std::array<State, 16> updateRules, const std::function<State(int x, int y)>& states);

private:
    int getIndex(int x, int y);

    bool checkState(int x, int y, State State);

    bool checkState(int i, State State);

public:
    /// <summary>
    /// Apply the update rules to all cells
    /// </summary>
    void update();

    /// <summary>
    /// Apply the update rules to all cells using cuda
    /// </summary>
    /// <param name="blockWidth">width of cuda block</param>
    /// <param name="blockHeight">height of cuda block</param>
    void updateCuda(unsigned int blockWidth, unsigned int blockHeight);

    /// <summary>
    /// Draws current frame to given output stream.
    /// Each byte represents the grayscale of a pixel (=one cell).
    /// </summary>
    /// <param name="out">Output stream</param>
    void draw(std::ostream& out);
};

CAIO::State operator&(const CAIO::State& lhs, const CAIO::State& rhs);
CAIO::State operator|(const CAIO::State& lhs, const CAIO::State& rhs);
CAIO::State& operator|=(CAIO::State& lhs, const CAIO::State& rhs);