#!/bin/bash

prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path="/prometheus"
