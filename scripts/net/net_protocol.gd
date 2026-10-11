class_name NetProtocol
extends RefCounted

# Raise VERSION whenever the RPC layer changes, so a mismatched app and server
# fail with a clear message instead of silently misbehaving.
const VERSION := 1
const DISCOVERY_PORT := 7778
const DISCOVERY_QUERY := "BATTLERIFT?"
const DISCOVERY_PREFIX := "BATTLERIFT"