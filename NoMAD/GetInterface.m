//
//  GetInterface.m
//  NoMAD
//
//  Created by Boushy, Phillip on 10/6/16.
//  Copyright © 2016 Trusource Labs. All rights reserved.
//

#import "GetInterface.h"

#include <sys/types.h>
#include <sys/sysctl.h>

// contains CTL_NET for networking
#include <sys/socket.h>

// For route
#include <net/if.h>

// For converting address
#include <net/if_dl.h>
#include <sys/ioctl.h>

// Needed for flags
# include <net/route.h>

// For converting hostname to IP.
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>


#import <ifaddrs.h>
#import <sys/param.h>
#import <stdio.h>

#define ROUNDUP(a) \
	((a) > 0 ? (1 + (((a) - 1) | (sizeof(uint32_t) - 1))) : sizeof(uint32_t))

typedef union {
	uint32_t dummy;		/* Helps align structure. */
	struct	sockaddr u_sa;
	u_short	u_data[128];
} sa_u;

@implementation GetInterface

+(NSString *)getInterfaceForAddress:(NSString *)address {
	const char *cAddress = [address UTF8String];
	NSString *interface;
	NSMutableArray *mutableRouteArray = [NSMutableArray array];
	NSString *ipAddress;
	
	if ( isValidIPAddress(address) ) {
		ipAddress = address;
		/*
		struct sockaddr_in dst;
		dst.sin_family = AF_INET;
		dst.sin_port = htons(6003);
		inet_pton(AF_INET, cAddress, &dst.sin_addr);
		
		int report = NULL;
		uint32_t flags = RTF_UP;
		struct rtentry *route_entry = rtalloc1(dst, report, flags);
		if (route_entry != NULL) {
			NSLog(@"route_entry is not NULL");
			//RT_LOCK_SPIN(route_entry);
			//if (route_entry->rt_ifp != NULL) {
				
			//}
			
		}
		
		//if ( rtisvalid(route_entry) ) {
			
		//}
		 */
	} else {
		struct addrinfo hints;
		memset(&hints, 0, sizeof(hints));
		hints.ai_family = PF_UNSPEC;
		hints.ai_protocol = IPPROTO_TCP;
		
		struct addrinfo *addrs, *addr;
		getaddrinfo(cAddress, NULL, &hints, &addrs);
		for (addr = addrs; addr; addr = addr->ai_next) {
			struct sockaddr_in *socketAddr;
			socketAddr = (struct sockaddr_in *)addr->ai_addr;
			//printf("inet_ntoa(in_addr)sin = %s\n",inet_ntoa((struct in_addr)addr->sin_addr));
			char *cIPAddress = inet_ntoa((struct in_addr)socketAddr->sin_addr);
			ipAddress = [NSString stringWithUTF8String: cIPAddress];
			break;
		}
	}
	
	int mibSize = 6; // This should match the number of items you have in the mibArray.
	size_t returnedValueLength;
	int mib[mibSize];
	char *returnedValueBuffer;
	register struct rt_msghdr2 *rtm;
	
	// The items we want from the routing table
	mib[0] = CTL_NET; // We want to get info from the network
	mib[1] = PF_ROUTE; // about routing
	mib[2] = 0; // protocol number, currently always 0.
	mib[3] = 0; // Address family. 0 = local, IPv4 and IPv6. AF_INET for IPv4, AF_INET for IPv6.
	mib[4] = NET_RT_DUMP2;
	// NET_RT_DUMP		1	/* dump; may limit to a.f. */
	// NET_RT_FLAGS		2	/* by flags, e.g. RESOLVING */
	// NET_RT_IFLIST		3	/* survey interface list */
	// NET_RT_STAT		4	/* routing statistics */
	// NET_RT_TRASH		5	/* routes not in table but not freed */
	// NET_RT_IFLIST2	6	/* interface list with addresses */
	// NET_RT_DUMP2		7	/* dump; may limit to a.f. */
	mib[5] = RTF_UP; //flags
	
	//Try to get the routing table based on settings above.
	//int sysctl_response = sysctl(mib, mibSize, returnedValueBuffer, &returnedValueLength, NULL, 0);
	if ( sysctl(mib, mibSize, NULL, &returnedValueLength, NULL, 0) < 0 ) {
		return nil;
	}
	
	if ( returnedValueLength <= 0 ) {
		return nil;
	}
	
	if ( (returnedValueBuffer = malloc(returnedValueLength)) == 0 ) {
		NSLog(@"malloc %ld buffer error", (long)returnedValueLength);
		return nil;
	}
	if ( returnedValueBuffer && sysctl(mib, mibSize, returnedValueBuffer, &returnedValueLength, NULL, 0) == 0) {
		for ( char * ptr = returnedValueBuffer; ptr < returnedValueBuffer + returnedValueLength; ptr += rtm->rtm_msglen ) {
			rtm = (struct rt_msghdr2 *)ptr;
			
			struct sockaddr *dst_sa = (struct sockaddr *)(rtm + 1);
			if (rtm->rtm_addrs & RTA_DST) {
				//Don't print protocol-cloned routes unless -a.
				if (dst_sa->sa_family == AF_INET && !((rtm->rtm_flags & RTF_WASCLONED) && (rtm->rtm_parentflags & RTF_PRCLONING))) {
					struct sockaddr *sa = (struct sockaddr*)(rtm + 1);
					//get_rtaddrs(rtm->rtm_addrs, sa, rti_info);
					int i;
					struct sockaddr *rti_info[RTAX_MAX];
					int addrs = rtm->rtm_addrs;
					for (i = 0; i < RTAX_MAX; i++) {
						if ( addrs & (1 << i) ) {
							rti_info[i] = sa;
							sa = (struct sockaddr *)(ROUNDUP(sa->sa_len) + (char *)sa);
							/*
							if ( sa != nil ) {
								if ( getDestination(*rtm, rti_info) == address ) {
									NSString *interface = getInterface(*rtm);
								}
							}
							 */
						} else {
							rti_info[i] = NULL;
						}
					}
					
				}
			}
		}
	}
	free(returnedValueBuffer);
	
	return interface;
}

BOOL isValidIPAddress(NSString *address) {
	const char *utf8 = [address UTF8String];
	int success;
	
	struct in_addr dst;
	success = inet_pton(AF_INET, utf8, &dst);
	if (success != 1) {
		struct in6_addr dst6;
		success = inet_pton(AF_INET6, utf8, &dst6);
	}
	
	return success == 1;
}

NSString *getDestination(register struct rt_msghdr2 m_rtm, struct sockaddr *rti_info[RTAX_MAX]) {
	sa_u dst, netmask;
	bzero(&dst, sizeof(dst));
	if (m_rtm.rtm_addrs & RTA_DST) {
		bcopy(rti_info[RTAX_DST], &dst, rti_info[RTAX_DST]->sa_len);
	}
	
	bzero(&netmask, sizeof(netmask));
	if (m_rtm.rtm_addrs & RTA_NETMASK) {
		bcopy(rti_info[RTAX_NETMASK], &netmask, rti_info[RTAX_NETMASK]->sa_len);
	}
	
	char *finalDst = p_sockaddr(&dst.u_sa, &netmask.u_sa, m_rtm.rtm_flags);
	if (finalDst != NULL) {
		return [NSString stringWithCString:finalDst encoding:NSASCIIStringEncoding];
	} else {
		return nil;
	}
}

NSString *getInterface(register struct rt_msghdr2 m_rtm) {
	char ifName[IF_NAMESIZE];
	char *name = if_indextoname(m_rtm.rtm_index, ifName);
	if (name != NULL) {
		return [NSString stringWithCString:name encoding:NSASCIIStringEncoding];
	} else {
		return nil;
	}
}

char *
p_sockaddr(struct sockaddr *sa, struct sockaddr *mask, int flags)
{
	char workbuf[128], *cplim;
	char *cp = workbuf;
	
	switch(sa->sa_family) {
		case AF_INET: {
			struct sockaddr_in *sin = (struct sockaddr_in *)sa;
			
			if ((sin->sin_addr.s_addr == INADDR_ANY) &&
				mask &&
				(ntohl(((struct sockaddr_in *)mask)->sin_addr.s_addr) == 0L || mask->sa_len == 0))
				cp = "default" ;
			else if (flags & RTF_HOST)
				cp = routename(sin->sin_addr.s_addr);
			else if (mask) {
				cp = netname(sin->sin_addr.s_addr,
							 ntohl(((struct sockaddr_in *)mask)->
								   sin_addr.s_addr));
			}
			else
				cp = netname(sin->sin_addr.s_addr, 0L);
			break;
		}
			
			//#ifdef INET6
		case AF_INET6: {
			struct sockaddr_in6 *sa6 = (struct sockaddr_in6 *)sa;
			struct in6_addr *in6 = &sa6->sin6_addr;
			
			/*
			 * XXX: This is a special workaround for KAME kernels.
			 * sin6_scope_id field of SA should be set in the future.
			 */
			if (IN6_IS_ADDR_LINKLOCAL(in6) ||
				IN6_IS_ADDR_MC_NODELOCAL(in6) ||
				IN6_IS_ADDR_MC_LINKLOCAL(in6)) {
				/* XXX: override is ok? */
				sa6->sin6_scope_id = (u_int32_t)ntohs(*(u_short *)&in6->s6_addr[2]);
				*(u_short *)&in6->s6_addr[2] = 0;
			}
			
			if (flags & RTF_HOST)
				cp = routename6(sa6);
			else if (mask)
				cp = netname6(sa6, mask);
			else
				cp = netname6(sa6, NULL);
			break;
		}
			//#endif /*INET6*/
			
		case AF_LINK: {
			struct sockaddr_dl* sdl = (struct sockaddr_dl*)sa;
			if(sdl->sdl_nlen + sdl->sdl_alen + sdl->sdl_slen == 0)
			{
				(void) snprintf(workbuf, sizeof(workbuf), "link#%d", sdl->sdl_index);
				cp = workbuf;
			} else {
				cp = link_ntoa(sdl);
			}
			break;
		}
			
		default: {
			u_char *s = (u_char *)sa->sa_data, *slim;
			
			slim =  sa->sa_len + (u_char *) sa;
			cplim = cp + sizeof(workbuf) - 6;
			cp += snprintf(cp, sizeof(workbuf) - (cp - workbuf), "(%d)", sa->sa_family);
			while (s < slim && cp < cplim) {
				cp += snprintf(cp, sizeof(workbuf) - (cp - workbuf), " %02x", *s++);
				if (s < slim)
					cp += snprintf(cp, sizeof(workbuf) - (cp - workbuf), "%02x", *s++);
			}
			cp = workbuf;
		}
	}
	
	return cp;
}

char *
routename(uint32_t in)
{
	char *cp;
	static char line[MAXHOSTNAMELEN];
	struct hostent *hp;
	
	cp = 0;
	hp = gethostbyaddr((char *)&in, sizeof (struct in_addr),
					   AF_INET);
	if (hp) {
		cp = hp->h_name;
		trimdomain(cp, strlen(cp));
	}
	
	if (cp) {
		strncpy(line, cp, sizeof(line) - 1);
		line[sizeof(line) - 1] = '\0';
	} else {
#define C(x)	((x) & 0xff)
		in = ntohl(in);
		snprintf(line, sizeof(line), "%u.%u.%u.%u",
				 C(in >> 24), C(in >> 16), C(in >> 8), C(in));
	}
	return (line);
}

char *
routename6(struct sockaddr_in6 *sa6)
{
	static char line[MAXHOSTNAMELEN];
	int flag = NI_WITHSCOPEID;
	/* use local variable for safety */
	struct sockaddr_in6 sa6_local = {sizeof(sa6_local), AF_INET6, };
	
	sa6_local.sin6_addr = sa6->sin6_addr;
	sa6_local.sin6_scope_id = sa6->sin6_scope_id;
	
	getnameinfo((struct sockaddr *)&sa6_local, sa6_local.sin6_len,
				line, sizeof(line), NULL, 0, flag);
	
	return line;
}

/*
 * Return the name of the network whose address is given.
 * The address is assumed to be that of a net or subnet, not a host.
 */
char *
netname(uint32_t in, uint32_t mask)
{
	char *cp = 0;
	static char line[MAXHOSTNAMELEN];
	struct netent *np = 0;
	uint32_t net, omask, dmask;
	uint32_t i;
	
	i = ntohl(in);
	dmask = forgemask(i);
	omask = mask;
	//    if (!nflag && i) {
	if (i) {
		net = i & dmask;
		if (!(np = getnetbyaddr(i, AF_INET)) && net != i)
			np = getnetbyaddr(net, AF_INET);
		if (np) {
			cp = np->n_name;
			trimdomain(cp, strlen(cp));
		}
	}
	if (cp)
		strncpy(line, cp, sizeof(line) - 1);
	else {
		switch (dmask) {
			case IN_CLASSA_NET:
				if ((i & IN_CLASSA_HOST) == 0) {
					snprintf(line, sizeof(line), "%u", C(i >> 24));
					break;
				}
				/* FALLTHROUGH */
			case IN_CLASSB_NET:
				if ((i & IN_CLASSB_HOST) == 0) {
					snprintf(line, sizeof(line), "%u.%u",
							 C(i >> 24), C(i >> 16));
					break;
				}
				/* FALLTHROUGH */
			case IN_CLASSC_NET:
				if ((i & IN_CLASSC_HOST) == 0) {
					snprintf(line, sizeof(line), "%u.%u.%u",
							 C(i >> 24), C(i >> 16), C(i >> 8));
					break;
				}
				/* FALLTHROUGH */
			default:
				snprintf(line, sizeof(line), "%u.%u.%u.%u",
						 C(i >> 24), C(i >> 16), C(i >> 8), C(i));
				break;
		}
	}
	domask(line+strlen(line), i, omask);
	return (line);
}


char *
netname6(struct sockaddr_in6 *sa6, struct sockaddr *sam)
{
	static char line[MAXHOSTNAMELEN];
	u_char *lim;
	int masklen, illegal = 0, flag = NI_WITHSCOPEID;
	struct in6_addr *mask = sam ? &((struct sockaddr_in6 *)sam)->sin6_addr : 0;
	
	if (sam && sam->sa_len == 0) {
		masklen = 0;
	} else if (mask) {
		u_char *p = (u_char *)mask;
		for (masklen = 0, lim = p + 16; p < lim; p++) {
			switch (*p) {
			 case 0xff:
				 masklen += 8;
				 break;
			 case 0xfe:
				 masklen += 7;
				 break;
			 case 0xfc:
				 masklen += 6;
				 break;
			 case 0xf8:
				 masklen += 5;
				 break;
			 case 0xf0:
				 masklen += 4;
				 break;
			 case 0xe0:
				 masklen += 3;
				 break;
			 case 0xc0:
				 masklen += 2;
				 break;
			 case 0x80:
				 masklen += 1;
				 break;
			 case 0x00:
				 break;
			 default:
				 illegal ++;
				 break;
			}
		}
		if (illegal)
			fprintf(stderr, "illegal prefixlen\n");
	} else {
		masklen = 128;
	}
	if (masklen == 0 && IN6_IS_ADDR_UNSPECIFIED(&sa6->sin6_addr))
		return("default");
	
	getnameinfo((struct sockaddr *)sa6, sa6->sin6_len, line, sizeof(line),
				NULL, 0, flag);
	
	return line;
}



static uint32_t
forgemask(uint32_t a)
{
	uint32_t m;
	
	if (IN_CLASSA(a))
		m = IN_CLASSA_NET;
	else if (IN_CLASSB(a))
		m = IN_CLASSB_NET;
	else
		m = IN_CLASSC_NET;
	return (m);
}

static void
domask(char *dst, uint32_t addr, uint32_t mask)
{
	int b, i;
	
	if (!mask || (forgemask(addr) == mask)) {
		*dst = '\0';
		return;
	}
	i = 0;
	for (b = 0; b < 32; b++)
		if (mask & (1 << b)) {
			int bb;
			
			i = b;
			for (bb = b+1; bb < 32; bb++)
				if (!(mask & (1 << bb))) {
					i = -1;	/* noncontig */
					break;
				}
			break;
		}
	if (i == -1)
		snprintf(dst, sizeof(dst), "&0x%x", mask);
	else
		snprintf(dst, sizeof(dst), "/%d", 32-i);
}

static void
trimdomain(cp)
char *cp;
{
	char domain[MAXHOSTNAMELEN + 1];
	static int first = 1;
	char *s;
	
	if (first) {
		first = 0;
		s = strchr(domain, '.');
		if (gethostname(domain, MAXHOSTNAMELEN) == 0 && s != NULL) {
			(void) strcpy(domain, s + 1);
		} else {
			domain[0] = 0;
		}
	}
	
	if (domain[0]) {
		while ((cp = strchr(cp, '.'))) {
			if (!strcasecmp(cp + 1, domain)) {
				*cp = 0;        /* hit it */
				break;
			} else {
				cp++;
			}
		}
	}
}

@end
