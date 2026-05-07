<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import type { K8sMetricsResponse, K8sStatusResponse } from '@/types';

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
        error.value = e instanceof Error ? e.message : '無法取得 K8s 狀態';
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

const hpaActive = computed(() => (status.value?.hpa?.max_replicas ?? 0) > 0);

const replicaUtilization = computed(() => {
    const hpa = status.value?.hpa;
    if (!hpa || hpa.max_replicas === 0) {
        return 0;
    }
    return Math.round((hpa.current_replicas / hpa.max_replicas) * 100);
});

const metricsByPodName = computed(() => {
    const map: Record<string, { cpu: string; memory: string }> = {};
    for (const pod of metrics.value?.pods ?? []) {
        map[pod.name] = { cpu: pod.cpu, memory: pod.memory };
    }
    return map;
});

const phaseColor: Record<string, string> = {
    Running: 'bg-green-500',
    Pending: 'bg-yellow-500',
    Succeeded: 'bg-blue-500',
    Failed: 'bg-red-500',
    Unknown: 'bg-neutral-400',
};

function shortName(name: string): string {
    const parts = name.split('-');
    if (parts.length <= 2) {
        return name;
    }
    return parts.slice(0, -2).join('-') + '-' + parts.slice(-1)[0].slice(0, 5);
}
</script>

<template>
    <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
        <div class="mb-4 flex items-center justify-between">
            <h3 class="text-lg font-semibold">Kubernetes 狀態</h3>
            <span
                v-if="status"
                class="rounded-full px-2 py-0.5 text-xs font-semibold"
                :class="
                    status.in_cluster
                        ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100'
                        : 'bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300'
                "
            >
                {{ status.in_cluster ? 'In-Cluster' : '本機開發' }}
            </span>
        </div>

        <div v-if="error" class="rounded-lg border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
            {{ error }}
        </div>

        <template v-else-if="status">
            <!-- Not in cluster: show informative fallback -->
            <div v-if="!status.in_cluster" class="space-y-3">
                <div class="rounded-lg border border-dashed border-sidebar-border/70 bg-muted/50 p-4 text-sm text-muted-foreground dark:border-sidebar-border">
                    <p class="font-medium text-foreground">未在 K8s 叢集中執行</p>
                    <p class="mt-1 text-xs">
                        在本機開發模式下，K8s API 不可用。部署到 K3s 後可看到 Pod 副本、HPA 自動擴展、節點資源等即時資訊。
                    </p>
                </div>
                <div class="grid grid-cols-2 gap-3 opacity-50">
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">Pod 數量</div>
                        <div class="text-2xl font-bold">—</div>
                    </div>
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">HPA</div>
                        <div class="text-2xl font-bold">—</div>
                    </div>
                </div>
            </div>

            <!-- In-cluster: full status -->
            <template v-else>
                <!-- Summary tiles -->
                <div class="grid grid-cols-2 gap-3">
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">Pod 數量</div>
                        <div class="text-2xl font-bold">{{ status.pod_count }}</div>
                    </div>
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">HPA</div>
                        <div class="text-2xl font-bold">{{ hpaActive ? '啟用中' : '未啟用' }}</div>
                    </div>
                </div>

                <!-- HPA details -->
                <div v-if="hpaActive" class="mt-4 rounded-lg bg-muted p-3">
                    <div class="mb-2 flex items-center justify-between text-xs">
                        <span class="text-muted-foreground">副本數</span>
                        <span class="font-mono">
                            {{ status.hpa.current_replicas }} / {{ status.hpa.min_replicas }}–{{ status.hpa.max_replicas }}
                        </span>
                    </div>
                    <div class="h-2 overflow-hidden rounded-full bg-background">
                        <div
                            class="h-full rounded-full bg-linear-to-r from-indigo-500 to-purple-500 transition-all duration-500"
                            :style="{ width: `${replicaUtilization}%` }"
                        />
                    </div>
                    <div v-if="status.hpa.desired_replicas !== status.hpa.current_replicas" class="mt-1.5 text-xs text-muted-foreground">
                        目標副本：{{ status.hpa.desired_replicas }}（擴縮中）
                    </div>
                </div>

                <!-- Pod list -->
                <div v-if="status.pods.length" class="mt-4">
                    <h4 class="mb-2 text-sm font-medium">Pod 列表</h4>
                    <div class="space-y-1.5">
                        <div
                            v-for="pod in status.pods"
                            :key="pod.name"
                            class="flex items-center justify-between gap-2 rounded-lg bg-muted px-3 py-2 text-xs"
                        >
                            <div class="flex min-w-0 items-center gap-2">
                                <span
                                    class="size-2 shrink-0 rounded-full"
                                    :class="phaseColor[pod.phase] ?? 'bg-neutral-400'"
                                    :title="pod.phase"
                                />
                                <span class="truncate font-mono" :title="pod.name">{{ shortName(pod.name) }}</span>
                                <span
                                    v-if="!pod.ready"
                                    class="rounded bg-yellow-100 px-1 text-[10px] font-medium text-yellow-800 dark:bg-yellow-900 dark:text-yellow-100"
                                >
                                    未就緒
                                </span>
                            </div>
                            <div v-if="metricsByPodName[pod.name]" class="flex shrink-0 gap-3 text-muted-foreground">
                                <span>CPU：{{ metricsByPodName[pod.name].cpu }}</span>
                                <span>記憶體：{{ metricsByPodName[pod.name].memory }}</span>
                            </div>
                        </div>
                    </div>
                </div>
            </template>
        </template>

        <div v-else class="space-y-3">
            <div class="h-16 animate-pulse rounded-lg bg-muted" />
            <div class="h-16 animate-pulse rounded-lg bg-muted" />
        </div>
    </div>
</template>
