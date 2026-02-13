<?php

use App\Services\MonteCarloService;

test('calculate returns correct structure', function () {
    $service = new MonteCarloService;
    $result = $service->calculate(100000);

    expect($result)->toBeArray()
        ->toHaveKeys(['pi', 'inside', 'total', 'duration_ms']);

    expect($result['pi'])->toBeFloat();
    expect($result['inside'])->toBeInt();
    expect($result['total'])->toBe(100000);
    expect($result['duration_ms'])->toBeInt();
});

test('calculate pi is within reasonable range for small sample', function () {
    $service = new MonteCarloService;
    $result = $service->calculate(100000);

    expect($result['pi'])->toBeGreaterThan(2.8)
        ->toBeLessThan(3.5);
});

test('calculate pi is within tighter range for large sample', function () {
    $service = new MonteCarloService;
    $result = $service->calculate(1000000);

    expect($result['pi'])->toBeGreaterThan(3.0)
        ->toBeLessThan(3.3);
});

test('calculate throws exception for points below minimum', function () {
    $service = new MonteCarloService;

    expect(fn () => $service->calculate(50000))
        ->toThrow(InvalidArgumentException::class);
});

test('calculate throws exception for points above maximum', function () {
    $service = new MonteCarloService;

    expect(fn () => $service->calculate(20000000))
        ->toThrow(InvalidArgumentException::class);
});

test('calculate accepts minimum valid points', function () {
    $service = new MonteCarloService;
    $result = $service->calculate(MonteCarloService::MIN_POINTS);

    expect($result)->toBeArray()
        ->toHaveKeys(['pi', 'inside', 'total', 'duration_ms']);
});

test('calculate accepts maximum valid points', function () {
    $service = new MonteCarloService;
    $result = $service->calculate(MonteCarloService::MAX_POINTS);

    expect($result)->toBeArray()
        ->toHaveKeys(['pi', 'inside', 'total', 'duration_ms']);
});

test('calculate duration is positive', function () {
    $service = new MonteCarloService;
    $result = $service->calculate(100000);

    expect($result['duration_ms'])->toBeGreaterThan(0);
});

test('calculate inside count is less than or equal to total', function () {
    $service = new MonteCarloService;
    $result = $service->calculate(100000);

    expect($result['inside'])->toBeLessThanOrEqual($result['total']);
});
