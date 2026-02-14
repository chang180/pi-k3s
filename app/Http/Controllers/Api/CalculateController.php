<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCalculationRequest;
use App\Models\Calculation;
use App\Services\DistributedCalculator;
use App\Services\MonteCarloService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\StreamedEvent;
use Symfony\Component\HttpFoundation\StreamedResponse;

class CalculateController extends Controller
{
    public function __construct(
        public MonteCarloService $monteCarloService,
        public DistributedCalculator $distributedCalculator
    ) {}

    /**
     * Store a newly created calculation and execute it.
     * For mode=distributed returns 202 and processes via queue.
     */
    public function store(StoreCalculationRequest $request): JsonResponse
    {
        $mode = $request->validated('mode', 'single');
        $calculation = Calculation::create([
            'total_points' => $request->validated('total_points'),
            'mode' => $mode,
            'status' => 'running',
        ]);

        if ($mode === 'distributed') {
            try {
                $this->distributedCalculator->dispatch($calculation);

                return response()->json($calculation, 202);
            } catch (\Exception $e) {
                $calculation->update(['status' => 'failed']);

                return response()->json([
                    'message' => 'Calculation failed',
                    'error' => $e->getMessage(),
                ], 500);
            }
        }

        try {
            $result = $this->monteCarloService->calculate($calculation->total_points);

            $calculation->update([
                'result_pi' => $result['pi'],
                'result_inside' => $result['inside'],
                'result_total' => $result['total'],
                'duration_ms' => $result['duration_ms'],
                'status' => 'completed',
            ]);

            return response()->json($calculation, 201);
        } catch (\Exception $e) {
            $calculation->update(['status' => 'failed']);

            return response()->json([
                'message' => 'Calculation failed',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Display the specified calculation.
     */
    public function show(Calculation $calculation): JsonResponse
    {
        return response()->json($calculation);
    }

    /**
     * Stream real-time calculation progress via SSE.
     */
    public function stream(Calculation $calculation): StreamedResponse
    {
        return response()->eventStream(function () use ($calculation) {
            $maxIterations = 300;

            for ($i = 0; $i < $maxIterations; $i++) {
                $calculation->refresh();

                $completedChunks = $calculation->chunks()->where('status', 'completed')->get();
                $totalChunks = $calculation->chunks()->count();

                $insideSum = $completedChunks->sum('result_inside');
                $totalSum = $completedChunks->sum('result_total');
                $partialPi = $totalSum > 0 ? 4.0 * $insideSum / $totalSum : 0;

                $data = [
                    'id' => $calculation->id,
                    'uuid' => $calculation->uuid,
                    'status' => $calculation->status,
                    'completed_chunks' => $completedChunks->count(),
                    'total_chunks' => $totalChunks,
                    'partial_pi' => $partialPi,
                    'inside_count' => $insideSum,
                    'total_count' => $totalSum,
                    'result_pi' => $calculation->result_pi,
                    'duration_ms' => $calculation->duration_ms,
                ];

                yield new StreamedEvent(
                    event: 'update',
                    data: json_encode($data),
                );

                if (in_array($calculation->status, ['completed', 'failed'])) {
                    break;
                }

                sleep(1);
            }
        }, headers: ['X-Accel-Buffering' => 'no']);
    }

    /**
     * Return recent completed calculation history.
     */
    public function history(): JsonResponse
    {
        $calculations = Calculation::query()
            ->where('status', 'completed')
            ->orderByDesc('created_at')
            ->limit(30)
            ->get(['id', 'uuid', 'total_points', 'mode', 'result_pi', 'duration_ms', 'created_at']);

        return response()->json($calculations);
    }
}
