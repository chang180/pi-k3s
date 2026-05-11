<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\K8sClientService;
use Illuminate\Http\JsonResponse;

class K8sStatusController extends Controller
{
    public function __construct(public K8sClientService $k8s) {}

    /**
     * GET /api/k8s/status - Pod count and HPA status.
     */
    public function status(): JsonResponse
    {
        $pods = $this->k8s->getPods();
        $hpa = $this->k8s->getHpaStatus();

        return response()->json([
            'in_cluster' => $this->k8s->isInCluster(),
            'pod_count' => count($pods),
            'web_pod_count' => count(array_filter($pods, fn (array $pod): bool => ($pod['component'] ?? null) === 'web')),
            'worker_pod_count' => count(array_filter($pods, fn (array $pod): bool => ($pod['component'] ?? null) === 'worker')),
            'pods' => $pods,
            'hpa' => $hpa,
        ]);
    }

    /**
     * GET /api/k8s/metrics - CPU and Memory usage per pod.
     */
    public function metrics(): JsonResponse
    {
        $metrics = $this->k8s->getMetrics();

        return response()->json([
            'in_cluster' => $this->k8s->isInCluster(),
            'pods' => $metrics,
        ]);
    }

    /**
     * GET /api/k8s/events - Recent HPA scale events.
     */
    public function events(): JsonResponse
    {
        return response()->json([
            'in_cluster' => $this->k8s->isInCluster(),
            'events' => $this->k8s->getHpaEvents(),
        ]);
    }
}
