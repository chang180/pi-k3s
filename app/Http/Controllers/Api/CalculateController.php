<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCalculationRequest;
use App\Models\Calculation;
use App\Services\MonteCarloService;
use Illuminate\Http\JsonResponse;

class CalculateController extends Controller
{
    public function __construct(public MonteCarloService $monteCarloService) {}

    /**
     * Store a newly created calculation and execute it.
     */
    public function store(StoreCalculationRequest $request): JsonResponse
    {
        $calculation = Calculation::create([
            'total_points' => $request->validated('total_points'),
            'mode' => $request->validated('mode', 'single'),
            'status' => 'running',
        ]);

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
}
