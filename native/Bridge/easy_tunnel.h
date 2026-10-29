#ifndef EASY_TUNNEL_H
#define EASY_TUNNEL_H

typedef struct EasyTunnelBackend EasyTunnelBackend;
// The event JSON is borrowed and must be copied before the callback returns.
typedef void (*EasyTunnelEventCallback)(const char *json);

EasyTunnelBackend *easy_tunnel_create(const char *data_dir, const char *home_dir, EasyTunnelEventCallback callback);
char *easy_tunnel_request(EasyTunnelBackend *backend, const char *request);
void easy_tunnel_free_string(char *value);
void easy_tunnel_destroy(EasyTunnelBackend *backend);

#endif
