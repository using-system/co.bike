import Link from 'next/link';
import { useRouter } from 'next/router';

const Toolbox = () => {
  const router = useRouter();
  const currentPath = router.pathname;

  const linkStyle = (path) => ({
    color: currentPath === path ? '#fff' : '#aaa',
    fontWeight: 'normal',
    padding: '10px',
    borderBottom: currentPath === path ? '2px solid #fff' : 'none'
  });

  return (
    <div style={{ display: 'flex', justifyContent: 'space-around', padding: '10px 0', borderTop: '1px solid #444', borderBottom: '1px solid #444', backgroundColor: '#222' }}>
      <Link href="/" passHref legacyBehavior>
        <a style={linkStyle('/')}>
          <svg width="24" height="24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
            <path d="M3 3h18v18H3V3z" fill="none" />
            <path d="M12 2C8.13 2 5 5.13 5 9c0 3.66 3.7 6.45 7 10.35C15.3 15.45 19 12.66 19 9c0-3.87-3.13-7-7-7zm0 11c-2.21 0-4-1.79-4-4s1.79-4 4 4-1.79 4-4 4z" />
          </svg>
        </a>
      </Link>
      <Link href="/account" passHref legacyBehavior>
        <a style={linkStyle('/account')}>
          <svg width="24" height="24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 12c2.67 0 8 1.34 8 4v2H4v-2c0-2.66 5.33-4 8-4zm0-2a3 3 0 110-6 3 3 0 010 6z" />
          </svg>
        </a>
      </Link>
    </div>
  );
};

export default Toolbox;