<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import type { K8sStatusResponse, K8sMetricsResponse } from '@/types';

const status = ref<K8sStatusResponse | null>(null);
const metrics = ref<K8sMetricsResponse | null>(null);
const error = ref<string | null>(null);

let pollInterval: ReturnType<typeof setInterval> | null = null;

async function fetchData(): Promise<void> {
    try {
        const [statusRes, metricsRes] = await Promise.all([
            fetch('/api/k8s/status', { headers: { Accept: 'application/json' } }),
            fetch('/api/k8s/metrics', { headers: { Accept: 'application/json' } }),
        ]);
        status.value = await statusRes.json();
        metrics.value = await metricsRes.json();
        error.value = null;
    } catch (e) {
        error.value = e instanceof Error ? e.message : 'Failed to fetch K8s status';
    }
}

onMounted(() => {
    fetchData();
    pollInterval = setInterval(fetchData, 5000);
});

onUnmounted(() => {
    if (pollInterval) {
        clearInterval(pollInterval);
    }
});
</script>

<template>
    <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
        <h3 class="mb-4 text-lg font-semibold">Kubernetes Status</h3>

        <div v-if="error" class="rounded-lg border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
            {{ error }}
        </div>

        <template v-else-if="status">
            <div v-if="!status.in_cluster" class="mb-3 rounded-lg bg-muted p-3 text-sm text-muted-foreground">
                Not running in K8s cluster (development mode)
            </div>

            <div class="grid grid-cols-2 gap-3">
                <!-- Pod Count -->
                <div class="rounded-lg bg-muted p-3">
                    <div class="text-xs text-muted-foreground">Pods</div>
                    <div class="text-2xl font-bold">{{ status.pod_count }}</div>
                </div>

                <!-- HPA Status -->
                <div class="rounded-lg bg-muted p-3">
                    <div class="text-xs text-muted-foreground">HPA</div>
                    <div class="text-2xl font-bold">
                        {{ status.hpa?.max_replicas ? 'Active' : 'Off' }}
                    </div>
                </div>

                <!-- HPA Details -->
                <template v-if="status.hpa?.max_replicas">
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">Replicas</div>
                        <div class="text-lg font-semibold">
                            {{ status.hpa.current_replicas }} / {{ status.hpa.min_replicas }}-{{ status.hpa.max_replicas }}
                        </div>
                    </div>
                </template>
            </div>

            <!-- Pod Metrics -->
            <div v-if="metrics?.pods?.length" class="mt-4">
                <h4 class="mb-2 text-sm font-medium">Pod Metrics</h4>
                <div class="space-y-2">
                    <div
                        v-for="pod in metrics.pods"
                        :key="pod.name"
                        class="flex items-center justify-between rounded-lg bg-muted p-2 text-sm"
                    >
                        <span class="truncate font-mono text-xs">{{ pod.name }}</span>
                        <div class="flex gap-3 text-xs text-muted-foreground">
                            <span>CPU: {{ pod.cpu }}</span>
                            <span>Mem: {{ pod.memory }}</span>
                        </div>
                    </div>
                </div>
            </div>
        </template>

        <div v-else class="space-y-3">
            <div class="h-16 animate-pulse rounded-lg bg-muted" />
            <div class="h-16 animate-pulse rounded-lg bg-muted" />
        </div>
    </div>
</template>
