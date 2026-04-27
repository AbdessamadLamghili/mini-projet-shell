#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <arpa/inet.h>
#include <unistd.h>

// Structure pour passer les arguments au thread
typedef struct {
    char *ip;
    int port;
} target_t;

void *check_port(void *arg) {
    target_t *target = (target_t *)arg;
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        free(target);
        return NULL;
    }
    struct sockaddr_in addr;
    
    struct timeval timeout;
    timeout.tv_sec = 2; // Timeout de 2 secondes
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    addr.sin_family = AF_INET;
    addr.sin_port = htons(target->port);
    addr.sin_addr.s_addr = inet_addr(target->ip);

    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) == 0) {
        printf("[OK] Port %d est OUVERT sur %s\n", target->port, target->ip);
    } else {
        printf("[FAIL] Port %d est FERMÉ sur %s\n", target->port, target->ip);
    }
    close(sock);
    free(target);
    return NULL;
}

int main() {
    int ports[] = {80, 443, 22, 3306}; // Ports à tester
    int n = sizeof(ports) / sizeof(ports[0]);
    pthread_t threads[n];

    for (int i = 0; i < n; i++) {
        target_t *t = malloc(sizeof(target_t));
        t->ip = "127.0.0.1";
        t->port = ports[i];
        pthread_create(&threads[i], NULL, check_port, t);
    }

    for (int i = 0; i < n; i++) pthread_join(threads[i], NULL);
    return 0;
}