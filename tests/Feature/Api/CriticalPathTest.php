<?php

use App\Models\Calculation;

test('end-to-end single mode: create, show, and history', function () {
    // Step 1: Create calculation
    $createResponse = $this->postJson('/api/calculate', [
        'total_points' => 100000,
        'mode' => 'single',
    ]);

    $createResponse->assertCreated();
    $id = $createResponse->json('id');
    $uuid = $createResponse->json('uuid');

    // Step 2: Retrieve by ID
    $showResponse = $this->getJson("/api/calculate/{$id}");
    $showResponse->assertSuccessful()
        ->assertJson([
            'id' => $id,
            'status' => 'completed',
        ]);

    // Step 3: Retrieve by UUID
    $uuidResponse = $this->getJson("/api/calculate/{$uuid}");
    $uuidResponse->assertSuccessful()
        ->assertJson(['id' => $id]);

    // Step 4: Appears in history
    $historyResponse = $this->getJson('/api/history');
    $historyResponse->assertSuccessful();

    $ids = collect($historyResponse->json())->pluck('id')->toArray();
    expect($ids)->toContain($id);
});

test('end-to-end distributed mode: create, stream, and verify completion', function () {
    \Illuminate\Support\Facades\Config::set('queue.default', 'database');

    // Step 1: Create distributed calculation
    $createResponse = $this->postJson('/api/calculate', [
        'total_points' => 500_000,
        'mode' => 'distributed',
    ]);

    $createResponse->assertStatus(202);
    $id = $createResponse->json('id');

    // Step 2: Process chunks manually
    $calculation = Calculation::find($id);
    $monteCarlo = app(\App\Services\MonteCarloService::class);

    foreach ($calculation->chunks as $chunk) {
        (new \App\Jobs\CalculatePiJob($calculation->id, $chunk->chunk_index, $chunk->total_points))
            ->handle($monteCarlo);
    }

    // Step 3: Stream should complete immediately for finished calculation
    $streamResponse = $this->get("/api/calculate/{$id}/stream");
    $streamResponse->assertSuccessful();
    $content = $streamResponse->streamedContent();
    expect($content)->toContain('"status":"completed"');

    // Step 4: Verify in history
    $historyResponse = $this->getJson('/api/history');
    $ids = collect($historyResponse->json())->pluck('id')->toArray();
    expect($ids)->toContain($id);
});

test('k8s status and metrics endpoints return valid structure', function () {
    $statusResponse = $this->getJson('/api/k8s/status');
    $statusResponse->assertSuccessful()
        ->assertJsonStructure(['in_cluster', 'pod_count', 'pods', 'hpa']);

    $metricsResponse = $this->getJson('/api/k8s/metrics');
    $metricsResponse->assertSuccessful()
        ->assertJsonStructure(['in_cluster', 'pods']);
});

test('history returns empty array when no completed calculations exist', function () {
    $response = $this->getJson('/api/history');

    $response->assertSuccessful();
    expect($response->json())->toBeArray()->toBeEmpty();
});
