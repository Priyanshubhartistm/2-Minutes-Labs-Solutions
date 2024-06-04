# VPC Flow Logs - Analyzing Network Traffic || [GSP212](https://www.cloudskillsboost.google/focuses/1236?parent=catalog) ||

## Solution [here]()

### Run the following Commands in CloudShell
```
export ZONE=
```
```
curl -LO raw.githubusercontent.com/QUICK-GCP-LAB/2-Minutes-Labs-Solutions/main/VPC%20Flow%20Logs%20-%20Analyzing%20Network%20Traffic/gsp212-1.sh

sudo chmod +x gsp212-1.sh

./gsp212-1.sh
```

* Go to `allow-http-ssh` Firewall from [here](https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/details/allow-http-ssh?)

* Go to `Create sink` from [here](https://console.cloud.google.com/logs/router/sink?)

* For `Sink Name`, type or paste `vpc-flows` 

* Paste the following in `Build inclusion filter` and Change PROJECT_ID

```
resource.type="gce_subnetwork"
log_name="projects/PROJECT_ID/logs/compute.googleapis.com%2Fvpc_flows"
```

### Again run the following Commands in CloudShell

```
curl -LO raw.githubusercontent.com/QUICK-GCP-LAB/2-Minutes-Labs-Solutions/main/VPC%20Flow%20Logs%20-%20Analyzing%20Network%20Traffic/gsp212-2.sh

sudo chmod +x gsp212-2.sh

./gsp212-2.sh
```

### Congratulations 🎉 for Completing the Lab !

##### *You Have Successfully Demonstrated Your Skills And Determination.*

#### *Well done!*

#### Don't Forget to Join the [Telegram Channel](https://t.me/QuickGcpLab) & [Discussion group](https://t.me/QuickGcpLabChats)

# [QUICK GCP LAB](https://www.youtube.com/@quickgcplab)