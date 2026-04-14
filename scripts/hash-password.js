import bcrypt from 'bcrypt';

async function hashPassword() {
  const password = 'test123456';
  const hashedPassword = await bcrypt.hash(password, 10);
  console.log('Email: test@example.com');
  console.log('Password: test123456');
  console.log('Hashed:', hashedPassword);
}

hashPassword();
