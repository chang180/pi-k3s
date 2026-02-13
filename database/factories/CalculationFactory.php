<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Calculation>
 */
class CalculationFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'total_points' => fake()->randomElement([100000, 1000000, 10000000]),
            'mode' => 'single',
            'status' => 'pending',
            'result_pi' => null,
            'result_inside' => null,
            'result_total' => null,
            'duration_ms' => null,
        ];
    }

    /**
     * Indicate that the calculation is completed.
     */
    public function completed(): static
    {
        return $this->state(function (array $attributes) {
            $totalPoints = $attributes['total_points'];
            $inside = (int) ($totalPoints * 0.785398);
            $pi = 4.0 * $inside / $totalPoints;

            return [
                'status' => 'completed',
                'result_pi' => $pi,
                'result_inside' => $inside,
                'result_total' => $totalPoints,
                'duration_ms' => fake()->numberBetween(100, 5000),
            ];
        });
    }

    /**
     * Indicate that the calculation is running.
     */
    public function running(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'running',
        ]);
    }

    /**
     * Indicate that the calculation has failed.
     */
    public function failed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'failed',
        ]);
    }
}
