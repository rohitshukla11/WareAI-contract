// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract InventoryEscrow {
    address public owner;

    struct Product {
        string name;
        uint256 price;
        uint256 stock;
    }

    struct Order {
        address buyer;
        uint256 productId;
        uint256 quantity;
        uint256 amount;
        bool fulfilled;
        bool refunded;
    }

    mapping(uint256 => Product) public products;
    mapping(uint256 => Order) public orders;
    mapping(uint256 => uint256) public escrow;

    uint256 public productCount;
    uint256 public orderCount;

    event ProductAdded(uint256 productId, string name, uint256 price, uint256 stock);
    event ProductRestocked(uint256 productId, uint256 newStock);
    event OrderPlaced(uint256 orderId, address buyer, uint256 productId, uint256 quantity, uint256 amount);
    event OrderFulfilled(uint256 orderId, address buyer, uint256 productId);
    event PaymentReleased(uint256 orderId, address seller, uint256 amount);
    event OrderRefunded(uint256 orderId, address buyer, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    function addProduct(string memory name, uint256 price, uint256 stock) public onlyOwner {
        require(price > 0, "Price must be greater than zero");
        require(stock > 0, "Stock must be greater than zero");

        productCount++;
        products[productCount] = Product(name, price, stock);
        emit ProductAdded(productCount, name, price, stock);
    }

    function restockProduct(uint256 productId, uint256 additionalStock) public onlyOwner {
        require(products[productId].stock > 0, "Product does not exist");
        products[productId].stock += additionalStock;
        emit ProductRestocked(productId, products[productId].stock);
    }

    function placeOrder(uint256 productId, uint256 quantity) public payable {
        require(products[productId].stock >= quantity, "Not enough stock available");
        uint256 totalPrice = products[productId].price * quantity;
        require(msg.value == totalPrice, "Incorrect payment amount");

        products[productId].stock -= quantity;
        orderCount++;
        orders[orderCount] = Order(msg.sender, productId, quantity, msg.value, false, false);
        escrow[orderCount] = msg.value;

        emit OrderPlaced(orderCount, msg.sender, productId, quantity, msg.value);
    }

    function fulfillOrder(uint256 orderId, address payable seller) public onlyOwner {
        require(orders[orderId].buyer != address(0), "Order does not exist");
        require(!orders[orderId].fulfilled, "Order already fulfilled");

        orders[orderId].fulfilled = true;
        uint256 amount = escrow[orderId];
        escrow[orderId] = 0;
        seller.transfer(amount);

        emit OrderFulfilled(orderId, orders[orderId].buyer, orders[orderId].productId);
        emit PaymentReleased(orderId, seller, amount);
    }

    function refundOrder(uint256 orderId) public onlyOwner {
        require(orders[orderId].buyer != address(0), "Order does not exist");
        require(!orders[orderId].fulfilled, "Order already fulfilled");
        require(!orders[orderId].refunded, "Order already refunded");

        orders[orderId].refunded = true;
        uint256 amount = escrow[orderId];
        escrow[orderId] = 0;
        payable(orders[orderId].buyer).transfer(amount);

        emit OrderRefunded(orderId, orders[orderId].buyer, amount);
    }
}
