<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Calculation extends Model
{
    /** @use HasFactory<\Database\Factories\CalculationFactory> */
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'uuid',
        'total_points',
        'mode',
        'status',
        'result_pi',
        'result_inside',
        'result_total',
        'duration_ms',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'total_points' => 'integer',
            'result_pi' => 'float',
            'result_inside' => 'integer',
            'result_total' => 'integer',
            'duration_ms' => 'integer',
        ];
    }

    /**
     * Retrieve the model for a bound value.
     *
     * @param  mixed  $value
     * @param  string|null  $field
     */
    public function resolveRouteBinding($value, $field = null): ?Model
    {
        if (Str::isUuid($value)) {
            return $this->where('uuid', $value)->first();
        }

        return $this->where('id', $value)->first();
    }

    protected static function booted(): void
    {
        static::creating(function (Calculation $calculation) {
            if (empty($calculation->uuid)) {
                $calculation->uuid = (string) Str::uuid();
            }
        });
    }
}
