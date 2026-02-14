<?php

test('k8s status returns json with pod_count and hpa', function () {
    $response = $this->getJson('/api/k8s/status');

    $response->assertOk()
        ->assertJsonStructure([
            'in_cluster',
            'pod_count',
            'pods',
            'hpa' => [
                'current_replicas',
                'desired_replicas',
                'min_replicas',
                'max_replicas',
            ],
        ]);
});

test('k8s metrics returns json with pods array', function () {
    $response = $this->getJson('/api/k8s/metrics');

    $response->assertOk()
        ->assertJsonStructure([
            'in_cluster',
            'pods',
        ]);
});
