FROM everpeace/curl-jq
COPY clean_dead_lease.sh /
CMD ["/clean_dead_lease.sh" ]
