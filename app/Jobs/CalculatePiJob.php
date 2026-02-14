<?php

namespace App\Jobs;

use App\Models\Calculation;
use App\Models\CalculationChunk;
use App\Services\MonteCarloService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class CalculatePiJob implements ShouldQueue
{
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    /**
     * The number of seconds the job can run before timing out.
     */
    public int $timeout = 600;

    /**
     * Create a new job instance.
     */
    public function __construct(
        public int $calculationId,
        public int $chunkIndex,
        public int $chunkPoints
    ) {
        $this->onConnection('database');
    }

    /**
     * Execute the job.
     */
    public function handle(MonteCarloService $monteCarloService): void
    {
        $chunk = CalculationChunk::query()
            ->where('calculation_id', $this->calculationId)
            ->where('chunk_index', $this->chunkIndex)
            ->firstOrFail();

        if ($chunk->status === 'completed') {
            return;
        }

        $result = $monteCarloService->calculate($this->chunkPoints);

        $chunk->update([
            'result_inside' => $result['inside'],
            'result_total' => $result['total'],
            'duration_ms' => $result['duration_ms'],
            'status' => 'completed',
        ]);

        $this->aggregateIfAllChunksComplete();
    }

    /**
     * If all chunks are completed, aggregate results to Calculation.
     */
    private function aggregateIfAllChunksComplete(): void
    {
        $lockKey = 'calculation_aggregate_'.$this->calculationId;

        $lock = \Illuminate\Support\Facades\Cache::lock($lockKey, 10);
        if (! $lock->get()) {
            return;
        }

        try {
            $calculation = Calculation::find($this->calculationId);
            if (! $calculation || $calculation->status !== 'running') {
                return;
            }

            $chunks = CalculationChunk::query()
                ->where('calculation_id', $this->calculationId)
                ->get();

            if ($chunks->contains('status', 'pending')) {
                return;
            }

            $totalInside = $chunks->sum('result_inside');
            $totalPoints = $chunks->sum('result_total');
            $totalDurationMs = $chunks->sum('duration_ms');

            $pi = $totalPoints > 0 ? 4.0 * $totalInside / $totalPoints : 0.0;

            $calculation->update([
                'result_pi' => $pi,
                'result_inside' => $totalInside,
                'result_total' => $totalPoints,
                'duration_ms' => $totalDurationMs,
                'status' => 'completed',
            ]);
        } finally {
            $lock->release();
        }
    }
}
