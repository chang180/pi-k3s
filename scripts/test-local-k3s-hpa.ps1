param(
    [string] $BaseUrl = 'http://localhost:8081',
    [string] $Namespace = 'pi-k3s-local',
    [int] $Requests = 12,
    [int] $Points = 10000000,
    [int] $PollCount = 12,
    [int] $PollSeconds = 10
)

$ErrorActionPreference = 'Stop'

Write-Host "Resetting worker deployment to 1 replica..."
kubectl scale deployment/laravel-worker -n $Namespace --replicas=1 | Out-Null
kubectl rollout status deployment/laravel-worker -n $Namespace --timeout=180s | Out-Null

Write-Host "Submitting $Requests distributed calculations to $BaseUrl ..."
for ($i = 1; $i -le $Requests; $i++) {
    $body = @{
        total_points = $Points
        mode = 'distributed'
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/calculate" -ContentType 'application/json' -Body $body
    Write-Host ("[{0}/{1}] calculation #{2} queued" -f $i, $Requests, $response.id)
}

Write-Host ""
Write-Host "Polling HPA and deployment status..."

for ($i = 1; $i -le $PollCount; $i++) {
    Write-Host ""
    Write-Host ("=== Poll {0}/{1} ===" -f $i, $PollCount)
    kubectl get hpa laravel-worker -n $Namespace
    kubectl get deployment laravel-worker -n $Namespace
    kubectl top pods -n $Namespace
    Start-Sleep -Seconds $PollSeconds
}

Write-Host ""
Write-Host "Final HPA details:"
kubectl describe hpa laravel-worker -n $Namespace
