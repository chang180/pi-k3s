<?php

namespace App\Services;

use App\Jobs\CalculatePiJob;
use App\Models\Calculation;
use App\Models\CalculationChunk;
use InvalidArgumentException;

class DistributedCalculator
{
    /**
     * Minimum number of chunks (each chunk at least MIN_CHUNK_POINTS).
     */
    public const MIN_CHUNK_POINTS = 50_000;

    /**
     * Dispatch chunk jobs for a calculation and return immediately.
     * Aggregation is done by the last completing CalculatePiJob.
     *
     * @throws InvalidArgumentException
     */
    public function dispatch(Calculation $calculation): void
    {
        $totalPoints = $calculation->total_points;
        if ($totalPoints < MonteCarloService::MIN_POINTS || $totalPoints > MonteCarloService::MAX_POINTS) {
            throw new InvalidArgumentException(
                sprintf(
                    'Total points must be between %d and %d',
                    MonteCarloService::MIN_POINTS,
                    MonteCarloService::MAX_POINTS
                )
            );
        }

        $numChunks = (int) min(8, max(2, ceil($totalPoints / 500_000)));
        $numChunks = min($numChunks, (int) floor($totalPoints / self::MIN_CHUNK_POINTS) ?: 1);
        $baseSize = (int) floor($totalPoints / $numChunks);
        $remainder = $totalPoints - $baseSize * $numChunks;

        for ($i = 0; $i < $numChunks; $i++) {
            $chunkPoints = $baseSize + ($i < $remainder ? 1 : 0);

            CalculationChunk::create([
                'calculation_id' => $calculation->id,
                'chunk_index' => $i,
                'total_points' => $chunkPoints,
                'status' => 'pending',
            ]);

            CalculatePiJob::dispatch($calculation->id, $i, $chunkPoints);
        }
    }
}
