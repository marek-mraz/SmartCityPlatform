if (checkRes.status === 404) {
          const res = await fetch(`${broker.endpointUrl}/ngsi-ld/v1/entities`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/ld+json',
              'NGSILD-Tenant': tenantName,
            },
            body: JSON.stringify(entityPayload)
          });
          console.log("CONTEXT BROKER RESPONSE", res);
          if (!res.ok) this.logger.error(`Context Broker error: ${await res.text()}`);
        } else if (checkRes.ok) {
          this.logger.log(`Entity ${entity.id} already exists in Context Broker`);
        } else {
          this.logger.error(`Context Broker check error: ${checkRes.status} ${checkRes.statusText} - ${await checkRes.text()}`);
        }
      } catch (err: any) {