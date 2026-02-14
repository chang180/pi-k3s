<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { Bar } from 'vue-chartjs';
import {
    Chart as ChartJS,
    CategoryScale,
    LinearScale,
    BarElement,
    Title,
    Tooltip,
    Legend,
} from 'chart.js';
import type { HistoryEntry } from '@/types';

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

const history = ref<HistoryEntry[]>([]);

async function fetchHistory(): Promise<void> {
    try {
        const res = await fetch('/api/history', { headers: { Accept: 'application/json' } });
        history.value = await res.json();
    } catch {
        // silently ignore
    }
}

function refresh(): void {
    fetchHistory();
}

onMounted(fetchHistory);

defineExpose({ refresh });

const chartData = computed(() => {
    const recent = history.value.slice(0, 15);

    return {
        labels: recent.map((e) => {
            const pts = e.total_points >= 1_000_000 ? `${e.total_points / 1_000_000}M` : `${e.total_points / 1_000}K`;
            return `${pts} (${e.mode})`;
        }),
        datasets: [
            {
                label: 'Duration (ms)',
                data: recent.map((e) => e.duration_ms),
                backgroundColor: recent.map((e) =>
                    e.mode === 'single' ? 'rgba(99, 102, 241, 0.7)' : 'rgba(52, 211, 153, 0.7)',
                ),
                borderColor: recent.map((e) =>
                    e.mode === 'single' ? 'rgb(99, 102, 241)' : 'rgb(52, 211, 153)',
                ),
                borderWidth: 1,
            },
        ],
    };
});

const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
        legend: {
            labels: { color: '#9ca3af' },
        },
    },
    scales: {
        x: {
            ticks: { color: '#9ca3af', maxRotation: 45 },
            grid: { color: 'rgba(107, 114, 128, 0.2)' },
        },
        y: {
            ticks: { color: '#9ca3af' },
            grid: { color: 'rgba(107, 114, 128, 0.2)' },
            beginAtZero: true,
        },
    },
};
</script>

<template>
    <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
        <div class="mb-3 flex items-center justify-between">
            <h3 class="text-lg font-semibold">Performance Comparison</h3>
            <button
                type="button"
                class="rounded-lg border border-input bg-background px-3 py-1 text-xs transition-colors hover:bg-muted"
                @click="refresh"
            >
                Refresh
            </button>
        </div>

        <div v-if="history.length === 0" class="flex h-48 items-center justify-center text-sm text-muted-foreground">
            No completed calculations yet
        </div>
        <div v-else class="h-64">
            <Bar :data="chartData" :options="chartOptions" />
        </div>

        <div class="mt-3 flex gap-4 text-xs text-muted-foreground">
            <span>
                <span class="mr-1 inline-block h-2 w-2 rounded-full bg-indigo-500" />
                Single
            </span>
            <span>
                <span class="mr-1 inline-block h-2 w-2 rounded-full bg-emerald-400" />
                Distributed
            </span>
        </div>
    </div>
</template>
