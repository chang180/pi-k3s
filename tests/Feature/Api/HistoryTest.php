<?php

use App\Models\Calculation;

test('history returns only completed calculations', function () {
    Calculation::factory()->completed()->count(3)->create();
    Calculation::factory()->running()->create();
    Calculation::factory()->failed()->create();

    $response = $this->getJson('/api/history');

    $response->assertSuccessful();
    expect($response->json())->toHaveCount(3);

    collect($response->json())->each(function (array $item) {
        expect($item)->toHaveKeys(['id', 'uuid', 'total_points', 'mode', 'result_pi', 'duration_ms', 'created_at']);
    });
});

test('history is ordered by newest first', function () {
    $older = Calculation::factory()->completed()->create(['created_at' => now()->subMinutes(10)]);
    $newer = Calculation::factory()->completed()->create(['created_at' => now()]);

    $response = $this->getJson('/api/history');

    $response->assertSuccessful();
    expect($response->json('0.id'))->toBe($newer->id);
    expect($response->json('1.id'))->toBe($older->id);
});

test('history limits to 30 results', function () {
    Calculation::factory()->completed()->count(35)->create();

    $response = $this->getJson('/api/history');

    $response->assertSuccessful();
    expect($response->json())->toHaveCount(30);
});

test('history returns correct json structure', function () {
    Calculation::factory()->completed()->create([
        'total_points' => 100000,
        'mode' => 'single',
    ]);

    $response = $this->getJson('/api/history');

    $response->assertSuccessful()
        ->assertJsonStructure([
            '*' => ['id', 'uuid', 'total_points', 'mode', 'result_pi', 'duration_ms', 'created_at'],
        ]);
});
