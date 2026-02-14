<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

/**
 * Fetch Pod and HPA status from Kubernetes API (in-cluster).
 * Uses ServiceAccount token when running inside K8s.
 */
class K8sClientService
{
    private ?string $baseUrl = null;

    private ?string $token = null;

    private ?string $namespace = null;

    public function __construct()
    {
        $host = config('services.kubernetes.host');
        $port = config('services.kubernetes.port');
        if ($host && $port) {
            $this->baseUrl = 'https://'.$host.':'.$port;
            $tokenPath = '/var/run/secrets/kubernetes.io/serviceaccount/token';
            $this->token = is_file($tokenPath) ? file_get_contents($tokenPath) : null;
            $nsPath = '/var/run/secrets/kubernetes.io/serviceaccount/namespace';
            $this->namespace = is_file($nsPath) ? trim(file_get_contents($nsPath)) : 'pi-k3s';
        }
    }

    /**
     * Whether we are running inside Kubernetes and can call the API.
     */
    public function isInCluster(): bool
    {
        return $this->baseUrl !== null && $this->token !== null;
    }

    /**
     * Get pods in the app namespace.
     *
     * @return array<int, array<string, mixed>>
     */
    public function getPods(): array
    {
        if (! $this->isInCluster()) {
            return [];
        }

        $url = $this->baseUrl.'/api/v1/namespaces/'.$this->namespace.'/pods';
        $response = $this->request('GET', $url);
        if (! $response || ! isset($response['items'])) {
            return [];
        }

        $list = [];
        foreach ($response['items'] as $item) {
            $list[] = [
                'name' => $item['metadata']['name'] ?? '',
                'phase' => $item['status']['phase'] ?? 'Unknown',
                'ready' => $this->podReady($item),
            ];
        }

        return $list;
    }

    /**
     * Get HPA status for the deployment.
     *
     * @return array{current_replicas: int, desired_replicas: int, min_replicas: int, max_replicas: int}
     */
    public function getHpaStatus(): array
    {
        if (! $this->isInCluster()) {
            return [
                'current_replicas' => 0,
                'desired_replicas' => 0,
                'min_replicas' => 0,
                'max_replicas' => 0,
            ];
        }

        $url = $this->baseUrl.'/apis/autoscaling/v2/namespaces/'.$this->namespace.'/horizontalpodautoscalers/laravel-app';
        $response = $this->request('GET', $url);
        if (! $response) {
            return [
                'current_replicas' => 0,
                'desired_replicas' => 0,
                'min_replicas' => 0,
                'max_replicas' => 0,
            ];
        }

        $status = $response['status'] ?? [];
        $spec = $response['spec'] ?? [];

        return [
            'current_replicas' => (int) ($status['currentReplicas'] ?? 0),
            'desired_replicas' => (int) ($status['desiredReplicas'] ?? 0),
            'min_replicas' => (int) ($spec['minReplicas'] ?? 0),
            'max_replicas' => (int) ($spec['maxReplicas'] ?? 0),
        ];
    }

    /**
     * Get pod metrics (CPU/Memory) if metrics-server is available.
     *
     * @return array<int, array{name: string, cpu: string, memory: string}>
     */
    public function getMetrics(): array
    {
        if (! $this->isInCluster()) {
            return [];
        }

        $url = $this->baseUrl.'/apis/metrics.k8s.io/v1beta1/namespaces/'.$this->namespace.'/pods';
        $response = $this->request('GET', $url);
        if (! $response || ! isset($response['items'])) {
            return [];
        }

        $list = [];
        foreach ($response['items'] as $item) {
            $usage = $item['containers'] ?? [];
            $cpu = '0';
            $memory = '0';
            foreach ($usage as $c) {
                $cpu = $c['usage']['cpu'] ?? '0';
                $memory = $c['usage']['memory'] ?? '0';
                break;
            }
            $list[] = [
                'name' => $item['metadata']['name'] ?? '',
                'cpu' => $cpu,
                'memory' => $memory,
            ];
        }

        return $list;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function request(string $method, string $url): ?array
    {
        $opts = [
            'verify' => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
        ];
        if (! is_file($opts['verify'])) {
            $opts['verify'] = false;
        }

        $req = Http::withToken($this->token)->withOptions($opts)->timeout(5);
        $response = $method === 'GET' ? $req->get($url) : $req->request($method, $url);

        if (! $response->successful()) {
            return null;
        }

        return $response->json();
    }

    /**
     * @param  array<string, mixed>  $pod
     */
    private function podReady(array $pod): bool
    {
        $conditions = $pod['status']['conditions'] ?? [];
        foreach ($conditions as $c) {
            if (($c['type'] ?? '') === 'Ready') {
                return ($c['status'] ?? '') === 'True';
            }
        }

        return false;
    }
}
