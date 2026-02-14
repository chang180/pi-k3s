<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CalculationChunk extends Model
{
    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'calculation_id',
        'chunk_index',
        'total_points',
        'result_inside',
        'result_total',
        'duration_ms',
        'status',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'calculation_id' => 'integer',
            'chunk_index' => 'integer',
            'total_points' => 'integer',
            'result_inside' => 'integer',
            'result_total' => 'integer',
            'duration_ms' => 'integer',
        ];
    }

    public function calculation(): BelongsTo
    {
        return $this->belongsTo(Calculation::class);
    }
}
