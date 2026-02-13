<?php

use App\Models\Calculation;

test('can create calculation with valid points', function () {
    $response = $this->postJson('/api/calculate', [
        'total_points' => 100000,
        'mode' => 'single',
    ]);

    $response->assertCreated()
        ->assertJsonStructure([
            'id',
            'uuid',
            'total_points',
            'mode',
            'status',
            'result_pi',
            'result_inside',
            'result_total',
            'duration_ms',
            'created_at',
            'updated_at',
        ])
        ->assertJson([
            'total_points' => 100000,
            'mode' => 'single',
            'status' => 'completed',
        ]);

    expect($response->json('result_pi'))->toBeFloat();
    expect($response->json('result_inside'))->toBeInt();
    expect($response->json('duration_ms'))->toBeInt();
});

test('can create calculation without mode defaults to single', function () {
    $response = $this->postJson('/api/calculate', [
        'total_points' => 1000000,
    ]);

    $response->assertCreated()
        ->assertJson([
            'mode' => 'single',
            'status' => 'completed',
        ]);
});

test('validates total points is required', function () {
    $response = $this->postJson('/api/calculate', [
        'mode' => 'single',
    ]);

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['total_points']);
});

test('validates total points must be integer', function () {
    $response = $this->postJson('/api/calculate', [
        'total_points' => 'not-a-number',
    ]);

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['total_points']);
});

test('validates total points minimum value', function () {
    $response = $this->postJson('/api/calculate', [
        'total_points' => 50000,
    ]);

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['total_points']);
});

test('validates total points maximum value', function () {
    $response = $this->postJson('/api/calculate', [
        'total_points' => 20000000,
    ]);

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['total_points']);
});

test('validates mode must be valid value', function () {
    $response = $this->postJson('/api/calculate', [
        'total_points' => 100000,
        'mode' => 'invalid-mode',
    ]);

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['mode']);
});

test('can retrieve existing calculation by id', function () {
    $calculation = Calculation::factory()->create([
        'total_points' => 100000,
        'mode' => 'single',
        'status' => 'completed',
        'result_pi' => 3.14159,
        'result_inside' => 78540,
        'result_total' => 100000,
        'duration_ms' => 150,
    ]);

    $response = $this->getJson("/api/calculate/{$calculation->id}");

    $response->assertOk()
        ->assertJson([
            'id' => $calculation->id,
            'uuid' => $calculation->uuid,
            'total_points' => 100000,
            'mode' => 'single',
            'status' => 'completed',
        ]);
});

test('can retrieve existing calculation by uuid', function () {
    $calculation = Calculation::factory()->create([
        'total_points' => 1000000,
        'mode' => 'single',
        'status' => 'completed',
        'result_pi' => 3.14159,
        'result_inside' => 785398,
        'result_total' => 1000000,
        'duration_ms' => 500,
    ]);

    $response = $this->getJson("/api/calculate/{$calculation->uuid}");

    $response->assertOk()
        ->assertJson([
            'id' => $calculation->id,
            'uuid' => $calculation->uuid,
            'total_points' => 1000000,
        ]);
});

test('returns 404 for non-existent calculation', function () {
    $response = $this->getJson('/api/calculate/99999');

    $response->assertNotFound();
});

test('calculation result pi is within reasonable range', function () {
    $response = $this->postJson('/api/calculate', [
        'total_points' => 1000000,
    ]);

    $response->assertCreated();

    $pi = $response->json('result_pi');
    expect($pi)->toBeGreaterThan(3.0)
        ->toBeLessThan(3.3);
});
