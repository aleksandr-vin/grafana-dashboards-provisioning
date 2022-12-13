local Annotation(expr, title, text, color, tags, name = expr) = {
  "datasource": "Kubernetes",
  "enable": true,
  "expr": expr,
  "hide": true,
  "iconColor": color,
  "name": name,
  "tagKeys": tags,
  "textFormat": text,
  "titleFormat": title,
  "useValueForTime": true
};

[
  Annotation("container_start_time_seconds{pod=~\"some-service-.*\"} * 1000",
             "Pod started",
             "{{pod}}",
             "#ad03fd",
             "start,pod,k8s",
             "container_start_time_seconds"),
]
