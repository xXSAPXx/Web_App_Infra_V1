const express = require('express');
const mysql = require('mysql2');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const bodyParser = require('body-parser');
const cors = require('cors'); // Add this line

const app = express();
const port = 3000;

// Middleware to enable CORS
app.use(cors()); // Add this line

app.use(bodyParser.json());

// MySQL database connection
const pool = mysql.createPool({
  host: 'database-1.c9cyo2wmq0yg.us-east-1.rds.amazonaws.com',
  user: 'admin',
  password: '12345678',
  database: 'CALC_APP_DB',
  connectionLimit: 10
});

// Test the MySQL connection
pool.getConnection((err, connection) => {
  if (err) {
    // Log the error to server.log
    logStream.write(`[${new Date().toISOString()}] Error connecting to MySQL: ${err.message}\n`);
    console.error('Error connecting to MySQL:', err);
    process.exit(1); // Exit the process with an error code
  } else {
    console.log('Connected to MySQL database');
    connection.release(); // Release the connection back to the pool
  }
});

// Registration endpoint
app.post('/register', async (req, res) => {
    const { username, password } = req.body;
    
    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        pool.query(
            'INSERT INTO users (username, password) VALUES (?, ?)',
            [username, hashedPassword],
            (error, results) => {
                if (error) {
                    console.error('Database error:', error);
                    return res.status(500).json({ error: 'Database error' });
                }
                res.status(201).json({ message: 'User registered successfully!' });
            }
        );
    } catch (error) {
        console.error('Registration failed:', error);
        res.status(500).json({ error: 'Registration failed' });
    }
});

// Login endpoint
app.post('/login', (req, res) => {
    const { username, password } = req.body;

    pool.query(
        'SELECT * FROM users WHERE username = ?',
        [username],
        async (error, results) => {
            if (error || results.length === 0) {
                console.error('Invalid credentials:', error);
                return res.status(401).json({ error: 'Invalid credentials' });
            }
            const user = results[0];
            try {
                const match = await bcrypt.compare(password, user.password);
                if (!match) {
                    return res.status(401).json({ error: 'Invalid credentials' });
                }
                const token = jwt.sign({ id: user.id }, 'your_secret_key', { expiresIn: '1h' });
                res.json({ token });
            } catch (compareError) {
                console.error('Error comparing passwords:', compareError);
                res.status(500).json({ error: 'Login failed' });
            }
        }
    );
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
