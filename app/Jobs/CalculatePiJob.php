<?php

namespace App\Jobs;

use App\Models\Calculation;
use App\Models\CalculationChunk;
use App\Services\MonteCarloService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Throwable;

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
     * Retry failed chunks a few times without immediately hammering the queue.
     *
     * @var array<int, int>
     */
    public array $backoff = [1, 5, 10];

    /**
     * Create a new job instance.
     */
    public function __construct(
        public int $calculationId,
        public int $chunkIndex,
        public int $chunkPoints
    ) {}

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

        $result = $monteCarloService->calculateChunk($this->chunkPoints);

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

        $lock = Cache::lock($lockKey, 10);
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

    public function failed(?Throwable $exception): void
    {
        CalculationChunk::query()
            ->where('calculation_id', $this->calculationId)
            ->where('chunk_index', $this->chunkIndex)
            ->update(['status' => 'failed']);

        Calculation::query()
            ->whereKey($this->calculationId)
            ->where('status', 'running')
            ->update(['status' => 'failed']);
    }
}
