<?php

namespace App\Services;

use InvalidArgumentException;

class MonteCarloService
{
    public const MIN_POINTS = 100_000;

    public const MAX_POINTS = 10_000_000;

    /** Minimum points for a chunk (distributed mode splits total into smaller chunks). */
    public const MIN_CHUNK_POINTS = 1000;

    /**
     * Calculate Pi using Monte Carlo method (validates against API min/max).
     *
     * @return array{pi: float, inside: int, total: int, duration_ms: int}
     */
    public function calculate(int $totalPoints): array
    {
        if ($totalPoints < self::MIN_POINTS || $totalPoints > self::MAX_POINTS) {
            throw new InvalidArgumentException(
                sprintf(
                    'Total points must be between %d and %d',
                    self::MIN_POINTS,
                    self::MAX_POINTS
                )
            );
        }

        return $this->runMonteCarlo($totalPoints);
    }

    /**
     * Calculate Pi for a chunk (allows smaller point counts for distributed mode).
     *
     * @return array{pi: float, inside: int, total: int, duration_ms: int}
     */
    public function calculateChunk(int $chunkPoints): array
    {
        if ($chunkPoints < self::MIN_CHUNK_POINTS || $chunkPoints > self::MAX_POINTS) {
            throw new InvalidArgumentException(
                sprintf(
                    'Chunk points must be between %d and %d',
                    self::MIN_CHUNK_POINTS,
                    self::MAX_POINTS
                )
            );
        }

        return $this->runMonteCarlo($chunkPoints);
    }

    /**
     * Run Monte Carlo simulation (no validation).
     *
     * @return array{pi: float, inside: int, total: int, duration_ms: int}
     */
    private function runMonteCarlo(int $totalPoints): array
    {
        $startTime = microtime(true);
        $inside = 0;

        for ($i = 0; $i < $totalPoints; $i++) {
            $x = mt_rand() / mt_getrandmax();
            $y = mt_rand() / mt_getrandmax();

            if (($x * $x + $y * $y) <= 1.0) {
                $inside++;
            }
        }

        $pi = 4.0 * $inside / $totalPoints;
        $durationMs = (int) round((microtime(true) - $startTime) * 1000);

        return [
            'pi' => $pi,
            'inside' => $inside,
            'total' => $totalPoints,
            'duration_ms' => $durationMs,
        ];
    }
}
